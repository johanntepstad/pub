
# encoding: utf-8
# Query cache for managing frequently used queries

class QueryCache
  def initialize(cache_limit: 100)
    @cache = {}
    @cache_limit = cache_limit
  end

  def fetch_or_store(query, &block)
    if @cache.key?(query)
      @cache[query]
    else
      result = block.call
      store(query, result)
      result
    end
  end

  def clear_cache
    @cache.clear
  end

  private

  def store(query, result)
    @cache[query] = result
    trim_cache if @cache.size > @cache_limit
  end

  def trim_cache
    oldest_query = @cache.keys.first
    @cache.delete(oldest_query)
  end
end
