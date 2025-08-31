
# encoding: utf-8
# Centralized Weaviate integration utility

class WeaviateHelper
  def initialize(api_key:, url:)
    @client = Weaviate::Client.new(api_key: api_key, url: url)
  end

  def save_context(user_id:, text:)
    @client.create_object(
      class: "UserContext",
      properties: {
        user_id: user_id,
        text: text
      }
    )
  rescue StandardError => e
    log_error("Error saving context to Weaviate: #{e.message}")
  end

  def search_vector(vector)
    response = @client.query(vector: vector)
    response['data']['Get']['Document'].map { |doc| doc['content'] }.join("\n")
  rescue StandardError => e
    log_error("Error during vector search: #{e.message}")
    []
  end

  private

  def log_error(message)
    puts "[ERROR] #{message}"
  end
end
