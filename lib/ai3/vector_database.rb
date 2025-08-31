# frozen_string_literal: true

require "sqlite3"
require "json"

module Ai3
  # Vector database integration with Weaviate primary and SQLite fallback
  class VectorDatabase
    attr_reader :weaviate_client, :sqlite_db

    def initialize
      @weaviate_client = initialize_weaviate
      @sqlite_db = initialize_sqlite_fallback
      @use_weaviate = @weaviate_client&.healthy? || false
    end

    def store(prompt, response, session_id = nil)
      embedding = generate_embedding(prompt)
      
      data = {
        prompt: prompt,
        response: response,
        session_id: session_id,
        timestamp: Time.current.iso8601,
        embedding: embedding
      }

      if @use_weaviate && @weaviate_client.healthy?
        store_in_weaviate(data)
      else
        store_in_sqlite(data)
      end
    rescue StandardError => e
      Rails.logger.error "Vector storage failed: #{e.message}"
      # Fallback to SQLite
      store_in_sqlite(data) if @sqlite_db
    end

    def search(query, session_id: nil, limit: 5)
      embedding = generate_embedding(query)

      if @use_weaviate && @weaviate_client.healthy?
        search_weaviate(embedding, session_id: session_id, limit: limit)
      else
        search_sqlite(embedding, session_id: session_id, limit: limit)
      end
    rescue StandardError => e
      Rails.logger.error "Vector search failed: #{e.message}"
      search_sqlite(embedding, session_id: session_id, limit: limit)
    end

    def clear_session(session_id)
      if @use_weaviate && @weaviate_client.healthy?
        clear_weaviate_session(session_id)
      end
      
      clear_sqlite_session(session_id) if @sqlite_db
    rescue StandardError => e
      Rails.logger.error "Session clearing failed: #{e.message}"
    end

    def health_check
      {
        weaviate: @weaviate_client&.healthy? || false,
        sqlite: @sqlite_db != nil,
        primary: @use_weaviate ? "weaviate" : "sqlite"
      }
    end

    private

    def initialize_weaviate
      return nil unless Rails.application.credentials.weaviate_url

      WeaviateClient.new(
        url: Rails.application.credentials.weaviate_url,
        api_key: Rails.application.credentials.weaviate_api_key
      )
    rescue StandardError => e
      Rails.logger.warn "Weaviate initialization failed: #{e.message}"
      nil
    end

    def initialize_sqlite_fallback
      db_path = Rails.root.join("storage", "vector_cache.sqlite3")
      db = SQLite3::Database.new(db_path.to_s)
      
      # Create table if it doesn't exist
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS vectors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          prompt TEXT NOT NULL,
          response TEXT NOT NULL,
          session_id TEXT,
          timestamp TEXT NOT NULL,
          embedding TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      SQL

      # Create index for faster searches
      db.execute "CREATE INDEX IF NOT EXISTS idx_session_id ON vectors(session_id)"
      db.execute "CREATE INDEX IF NOT EXISTS idx_timestamp ON vectors(timestamp)"

      db
    rescue StandardError => e
      Rails.logger.error "SQLite fallback initialization failed: #{e.message}"
      nil
    end

    def generate_embedding(text)
      # Simple embedding generation using text features
      # In production, this would use a proper embedding model
      words = text.downcase.split(/\W+/).reject(&:empty?)
      
      # Create a simple bag-of-words embedding
      embedding = Array.new(384, 0.0) # Standard embedding dimension
      
      words.each_with_index do |word, idx|
        hash_value = word.hash % 384
        embedding[hash_value] += 1.0 / (idx + 1) # Position weighting
      end
      
      # Normalize
      norm = Math.sqrt(embedding.sum { |x| x * x })
      embedding.map { |x| norm > 0 ? x / norm : 0.0 }
    end

    def store_in_weaviate(data)
      @weaviate_client.create_object(
        class_name: "HealthcareContext",
        properties: {
          prompt: data[:prompt],
          response: data[:response].to_json,
          sessionId: data[:session_id],
          timestamp: data[:timestamp]
        },
        vector: data[:embedding]
      )
    end

    def store_in_sqlite(data)
      return unless @sqlite_db

      @sqlite_db.execute(
        "INSERT INTO vectors (prompt, response, session_id, timestamp, embedding) VALUES (?, ?, ?, ?, ?)",
        [
          data[:prompt],
          data[:response].to_json,
          data[:session_id],
          data[:timestamp],
          data[:embedding].to_json
        ]
      )
    end

    def search_weaviate(embedding, session_id: nil, limit: 5)
      where_clause = session_id ? { path: ["sessionId"], operator: "Equal", valueString: session_id } : nil

      results = @weaviate_client.query(
        class_name: "HealthcareContext",
        near_vector: embedding,
        limit: limit,
        where: where_clause
      )

      results.map { |result| parse_result(result) }
    end

    def search_sqlite(embedding, session_id: nil, limit: 5)
      return [] unless @sqlite_db

      sql = "SELECT prompt, response, session_id, timestamp, embedding FROM vectors"
      params = []

      if session_id
        sql += " WHERE session_id = ?"
        params << session_id
      end

      sql += " ORDER BY created_at DESC LIMIT ?"
      params << limit

      results = @sqlite_db.execute(sql, params)
      
      # Calculate similarity scores
      results.map do |row|
        stored_embedding = JSON.parse(row[4])
        similarity = cosine_similarity(embedding, stored_embedding)
        
        {
          prompt: row[0],
          response: JSON.parse(row[1]),
          session_id: row[2],
          timestamp: row[3],
          similarity: similarity
        }
      end.sort_by { |r| -r[:similarity] }
    end

    def clear_weaviate_session(session_id)
      @weaviate_client.delete_objects(
        class_name: "HealthcareContext",
        where: {
          path: ["sessionId"],
          operator: "Equal",
          valueString: session_id
        }
      )
    end

    def clear_sqlite_session(session_id)
      return unless @sqlite_db

      @sqlite_db.execute("DELETE FROM vectors WHERE session_id = ?", [session_id])
    end

    def parse_result(result)
      {
        prompt: result["properties"]["prompt"],
        response: JSON.parse(result["properties"]["response"]),
        session_id: result["properties"]["sessionId"],
        timestamp: result["properties"]["timestamp"],
        similarity: result["_additional"]["certainty"]
      }
    end

    def cosine_similarity(a, b)
      return 0.0 if a.length != b.length

      dot_product = a.zip(b).sum { |x, y| x * y }
      norm_a = Math.sqrt(a.sum { |x| x * x })
      norm_b = Math.sqrt(b.sum { |x| x * x })

      return 0.0 if norm_a == 0 || norm_b == 0

      dot_product / (norm_a * norm_b)
    end
  end

  # Simple Weaviate client implementation
  class WeaviateClient
    def initialize(url:, api_key: nil)
      @url = url
      @api_key = api_key
      @http = Net::HTTP.new(URI(@url).host, URI(@url).port)
      @http.use_ssl = @url.start_with?("https")
    end

    def healthy?
      response = @http.get("/v1/meta")
      response.code == "200"
    rescue StandardError
      false
    end

    def create_object(class_name:, properties:, vector: nil)
      payload = {
        class: class_name,
        properties: properties
      }
      payload[:vector] = vector if vector

      request = Net::HTTP::Post.new("/v1/objects")
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}" if @api_key
      request.body = payload.to_json

      response = @http.request(request)
      JSON.parse(response.body) if response.code == "200"
    end

    def query(class_name:, near_vector: nil, limit: 10, where: nil)
      payload = {
        query: build_graphql_query(class_name, near_vector, limit, where)
      }

      request = Net::HTTP::Post.new("/v1/graphql")
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}" if @api_key
      request.body = payload.to_json

      response = @http.request(request)
      result = JSON.parse(response.body)
      result.dig("data", "Get", class_name) || []
    end

    def delete_objects(class_name:, where:)
      payload = {
        match: where,
        output: "verbose"
      }

      request = Net::HTTP::Delete.new("/v1/batch/objects")
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}" if @api_key
      request.body = payload.to_json

      @http.request(request)
    end

    private

    def build_graphql_query(class_name, near_vector, limit, where)
      near_clause = near_vector ? "nearVector: { vector: #{near_vector} }" : ""
      where_clause = where ? "where: #{where.to_json}" : ""
      
      <<~GRAPHQL
        {
          Get {
            #{class_name}(
              limit: #{limit}
              #{near_clause}
              #{where_clause}
            ) {
              prompt
              response
              sessionId
              timestamp
              _additional {
                certainty
              }
            }
          }
        }
      GRAPHQL
    end
  end
end