# encoding: utf-8
#
# lib/langchain_wrapper.rb

require 'langchain'
require_relative '../lib/filesystem_tool'
require_relative '../lib/safe_execution'

class LangchainWrapper
  attr_reader :filesystem_tool, :safe_execution

  def initialize(api_key: ENV['OPENAI_API_KEY'])
    @llm_client = Langchain::LLM::OpenAI.new(
      api_key: api_key,
      llm_options: {
        model: "gpt-4-turbo",
      }
    )
    @filesystem_tool = FileSystemTool.new
    @safe_execution = SafeExecution.new
  end
end

