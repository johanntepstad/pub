
# encoding: utf-8
# Interactive session manager

require_relative 'memory_manager'

class InteractiveSession
  def initialize(rag_system, memory_manager)
    @rag_system = rag_system
    @memory_manager = memory_manager
  end

  def start
    puts "AI^3 Interactive Prompt"
    puts "Type your query and press Enter to get a response. Type 'exit' to quit."

    loop do
      print "You> "
      query = gets.chomp
      break if query.downcase == 'exit'

      context = @memory_manager.retrieve_memory
      response = @rag_system.generate_response("#{context} #{query}")
      @memory_manager.store_memory(query, response)
      puts "AI> #{response}"
    end
  end
end
