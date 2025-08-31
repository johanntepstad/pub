require_relative 'interactive_session'
require_relative 'professions/lawyer'
require_relative 'professions/hacker'
require_relative 'lib/translations'

module CliInitializer
  def self.start
    puts "Welcome to Enhanced GPT. Choose assistant:"
    puts "1. Lawyer"
    puts "2. Hacker"
    puts "3. Regular chat"
    print "Enter your choice: "
    choice = gets.chomp

    case choice
    when '1'
      InteractiveSession.new(profession: Professions::Lawyer.new('en')).start
    when '2'
      InteractiveSession.new(profession: Professions::Hacker.new).start
    when '3'
      InteractiveSession.new().start
    else
      puts "Invalid choice. Exiting."
      exit
    end
  end
end

