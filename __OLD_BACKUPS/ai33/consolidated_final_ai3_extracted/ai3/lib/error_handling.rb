
# encoding: utf-8
# Error Handling Library

class ErrorHandler
  def self.log_error(error, context = {})
    puts "[ERROR] #{error.message} - Context: #{context.inspect}"
  end
end
