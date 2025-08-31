# lib/command_executor.rb
require_relative 'filesystem_tool'

class CommandExecutor
  def initialize
    @filesystem_tool = FileSystemTool.new
  end

  def execute(command, params)
    case command
    when 'read', 'write', 'delete'
      @filesystem_tool.send(command, *params.split(' '))
    else
      "Command not recognized."
    end
  end
end

--

require 'langchain'

class CommandParser
  attr_reader :langchain_client

  def initialize(language: 'en', api_key: ENV['LANGCHAIN_API_KEY'])
    @langchain_client = Langchain::LLM::OpenAI.new(api_key: api_key, language: language)
  end

  def parse(input)
    response = @langchain_client.chat(prompt: "Interpret this command: #{input}")
    response.choices.first.text.strip.downcase
  end
end

