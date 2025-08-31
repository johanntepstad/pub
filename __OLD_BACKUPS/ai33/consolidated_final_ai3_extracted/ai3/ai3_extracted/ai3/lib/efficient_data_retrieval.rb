
require_relative 'weaviate_helper'

class EfficientDataRetrieval
  def initialize(weaviate_helper)
    @weaviate_helper = weaviate_helper
  end

  def search_vector(vector)
    @weaviate_helper.search_vector(vector)
  end
end
