require 'fileutils'
require 'logger'
require 'safe_ruby'

class FileSystemTool
  def self.read_file(path)
    if File.exist?(path) && File.readable?(path)
      SafeRuby.eval("File.read('#{path}')")  # Evaluate reading file safely.
    else
      "File not found or not readable"
    end
  rescue => e
    "Error reading file: #{e.message}"
  end

  def self.write_file(path, content)
    if File.writable?(path)
      SafeRuby.eval("File.open('#{path}', 'w') {|f| f.write('#{content}')}")
      "File written successfully"
    else
      "Permission denied"
    end
  rescue => e
    "Error writing file: #{e.message}"
  end

  def self.delete_file(path)
    if File.exist?(path)
      SafeRuby.eval("FileUtils.rm('#{path}')")
      "File deleted successfully"
    else
      "File not found"
    end
  rescue => e
    "Error deleting file: #{e.message}"
  end
end

