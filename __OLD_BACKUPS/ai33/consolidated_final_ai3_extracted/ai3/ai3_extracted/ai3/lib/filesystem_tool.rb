
# encoding: utf-8
# Filesystem tool for managing files

require 'fileutils'
require 'logger'
require 'safe_ruby'

class FileSystemTool
  def initialize
    @logger = Logger.new(STDOUT)
  end

  def read_file(path)
    return 'File not found or not readable' unless file_accessible?(path, :readable?)

    content = safe_eval("File.read(#{path.inspect})")
    log_action('read', path)
    content
  rescue => e
    handle_error('read', e)
  end

  def write_file(path, content)
    return 'Permission denied' unless file_accessible?(path, :writable?)

    safe_eval("File.write(#{path.inspect}, #{content.inspect})")
    log_action('write', path)
  rescue => e
    handle_error('write', e)
  end

  private

  def file_accessible?(path, permission)
    File.exist?(path) && File.send("#{permission}?", path)
  end

  def log_action(action, path)
    @logger.info("#{action.capitalize} operation performed on: #{path}")
  end

  def handle_error(action, error)
    ErrorHandler.handle(error, context: { action: action, path: path }, severity: :critical)
  end
end
