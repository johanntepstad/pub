
# encoding: utf-8
# Weaviate Helper for integrating with Weaviate's API

class WeaviateHelper
  def initialize(api_key:, url:)
    @client = Weaviate::Client.new(api_key: api_key, url: url)
  end

  def search_vector(vector)
    @client.query(vector: vector)
  end
end
