
class CommandHandler
  def initialize
    @commands = {}
  end

  def register_command(name, &block)
    @commands[name.to_sym] = block
  end

  def execute_command(name, *args)
    command = @commands[name.to_sym]
    if command
      command.call(*args)
    else
      log_error("Command \"#{name}\" not found")
    end
  rescue StandardError => e
    log_error("Error executing command \"#{name}\": #{e.message}")
  end

  private

  def log_error(message)
    puts "[ERROR] #{message}"
  end
end
