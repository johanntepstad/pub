
# encoding: utf-8
# Schema manager for handling schema evolution and integration

require_relative 'weaviate_helper'

class SchemaManager
  def initialize(weaviate_helper)
    @weaviate_helper = weaviate_helper
  end

  def create_schema(schema)
    with_error_handling do
      @weaviate_helper.create_schema(schema)
    end
  end

  def update_schema(schema)
    with_error_handling do
      @weaviate_helper.update_schema(schema)
    end
  end

  def delete_schema(schema_name)
    with_error_handling do
      @weaviate_helper.delete_schema(schema_name)
    end
  end

  def retrieve_schema(schema_name)
    with_error_handling do
      @weaviate_helper.get_schema(schema_name)
    end
  end

  private

  def with_error_handling
    yield
  rescue => e
    ErrorHandler.handle(e)
  end
end
