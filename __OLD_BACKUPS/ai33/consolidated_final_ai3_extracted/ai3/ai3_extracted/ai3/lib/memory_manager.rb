
# encoding: utf-8
# Memory manager for short-term and long-term memory handling

class MemoryManager
  def initialize(short_term_limit: 4096)
    @short_term_memory = []
    @long_term_memory = []
    @short_term_limit = short_term_limit
  end

  def store_memory(query, response)
    memory_entry = { query: query, response: response, timestamp: Time.now }
    @short_term_memory << memory_entry
    trim_short_term_memory
  end

  def retrieve_memory
    @short_term_memory.map { |entry| "#{entry[:query]}: #{entry[:response]}" }.join(" ")
  end

  def consolidate_memory
    @long_term_memory += @short_term_memory
    @short_term_memory.clear
  end

  private

  def trim_short_term_memory
    total_length = @short_term_memory.map { |entry| entry[:query].length + entry[:response].length }.sum
    @short_term_memory.shift while total_length > @short_term_limit
  end
end
