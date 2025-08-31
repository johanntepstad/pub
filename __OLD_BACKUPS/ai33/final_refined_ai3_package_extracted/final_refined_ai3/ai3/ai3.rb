#!/usr/bin/env ruby
# encoding: utf-8

require "openai"
require "langchain"
require "geometry"
require "safe_ruby"
require "httparty"

Dir[File.join(__dir__, 'lib', '*.rb')].each { |file| require_relative file }

# Load assistants if available
# ASSISTANT_DIR = File.join(__dir__, 'assistants')
# Dir[File.join(ASSISTANT_DIR, '**', '*.rb')].each { |file| require file }
# ASSISTANTS = ObjectSpace.each_object(Class).select { |klass| klass < AssistantBase }

class AI3
  def initialize
    @gpt4 = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])
    @assistants = load_assistants if defined?(ASSISTANTS)
  end

  def start_casual_chat
    puts "Starting a casual chat with GPT-4. Type 'exit' to quit."
    loop do
      print "You> "
      input = gets.chomp
      break if input.casecmp("exit").zero?

      response = @gpt4.chat(messages: [{ role: "user", content: input }], model: "gpt-4o").completion
      puts "GPT-4> #{response}"
    end
    post_chat_options
  end

  private

  def load_assistants
    ASSISTANTS.each_with_object({}) do |klass, hash|
      hash[klass.name.split('::').last.downcase.to_sym] = klass.new
    end
  end

  def post_chat_options
    puts "\nWhat would you like to do next?"
    puts "1. Interact with an assistant"
    puts "2. Exit"
    case gets.chomp.to_i
    when 1
      list_assistants
      print "Enter assistant name: "
      interact_with_assistant(gets.chomp)
    when 2
      puts "Exiting..."
      exit
    else
      puts "Invalid choice. Exiting..."
      exit
    end
  end

  def list_assistants
    puts "Available assistants:"
    @assistants.keys.each { |name| puts "- #{format_name(name)}" }
  end

  def interact_with_assistant(name)
    assistant = @assistants[name.to_sym]
    if assistant
      puts "Interacting with #{format_name(name)}..."
      interaction_loop(assistant, name)
    else
      puts "Assistant not found."
    end
  end

  def format_name(name)
    name.to_s.split('_').map(&:capitalize).join(' ')
  end

  def interaction_loop(assistant, name)
    loop do
      print "#{name.capitalize}> "
      input = gets.chomp
      break if input.casecmp("exit").zero?
      puts "AI> #{assistant.respond_to(input)}"
    end
  end
end

# Entry point
AI3.new.start_casual_chat if __FILE__ == $0

