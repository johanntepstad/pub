# encoding: utf-8

require 'langchain'

class WeaviateIntegration
  def initialize
    @weaviate = Langchain::Vectorsearch::Weaviate.new(
      url: ENV['WEAVIATE_URL'],
      api_key: ENV['WEAVIATE_API_KEY'],
      index_name: 'ProfessionData',
      llm: Langchain::LLM::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])
    )
    create_default_schema
  end

  def create_default_schema
    @weaviate.create_default_schema
  end

  def add_texts(texts)
    @weaviate.add_texts(texts: texts)
  end

  def similarity_search(query, k)
    @weaviate.similarity_search(query: query, k: k)
  end

  def check_if_indexed(url)
    indexed_urls.include?(url)
  end

  private

  def indexed_urls
    @indexed_urls ||= @weaviate.get_indexed_urls
  end
end
