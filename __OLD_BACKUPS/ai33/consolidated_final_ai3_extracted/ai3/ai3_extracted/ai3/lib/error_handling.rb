
class ErrorHandler
  def self.log_error(error, context = {}, severity = :error)
    # Enhanced logging with contextual information and severity levels
    log_message = "[#{severity.to_s.upcase}] #{error.message} - Context: #{context}"
    puts log_message
    write_to_logfile(log_message)
  end

  def self.handle(error, context = {}, severity = :error)
    log_error(error, context, severity)
    # Additional error handling logic
  end

  private

  def self.write_to_logfile(message)
    File.open('error_log.txt', 'a') do |file|
      file.puts("#{Time.now}: #{message}")
    end
  end
end
