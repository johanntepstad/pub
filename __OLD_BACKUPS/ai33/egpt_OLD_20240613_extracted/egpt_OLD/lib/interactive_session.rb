require_relative 'command_handler'
require_relative 'translations'

class InteractiveSession
  attr_reader :command_handler, :profession

  def initialize(profession: nil)
    @profession = profession
    @command_handler = CommandHandler.new(language: 'en')
  end

  def start
    if profession
      profession.conduct_interactive_consultation
    else
      general_chat_session
    end
  end

  private

  def general_chat_session
    puts TRANSLATIONS['en'][:welcome_message]
    loop do
      print TRANSLATIONS['en'][:user_prompt]
      input = gets.strip
      break if input.downcase == 'exit'
      puts @command_handler.handle_input(input)
    end
    puts TRANSLATIONS['en'][:session_end]
  end
end

