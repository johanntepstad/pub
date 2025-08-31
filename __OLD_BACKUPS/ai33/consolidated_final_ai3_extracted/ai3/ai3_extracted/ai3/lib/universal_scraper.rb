
#!/usr/bin/env ruby

require "kramdown"
require "ferrum"
require "logger"
require "fileutils"
require "openai"
require "langchain"

class UniversalScraper
  attr_reader :logger, :llm, :options

  def initialize(options = {})
    @options = {
      log_level: Logger::DEBUG,
      api_key: ENV["OPENAI_API_KEY"],
      humanize: true,
      validate: true,
      validation_min_length: 100,
      timeout: 120,
      process_timeout: 240,
      browser_path: "/usr/local/chrome/chrome",
      xvfb: true,
      unveil: true,
      js_wait_time: 10,
      retries: 3,
      take_screenshots: true
    }.merge(options)

    @logger = initialize_logger
    @llm = Langchain::LLM::OpenAI.new(api_key: @options[:api_key])
  end

  def scrape_and_analyze_page(url)
    browser = nil
    retry_on_failure(times: @options[:retries]) do
      browser = initialize_browser
      return unless browser

      humanize(browser) if @options[:humanize]

      log_message("Scraping started for: #{url}")
      browser.goto(url)

      if wait_for_js(browser)
        screenshot_path = take_screenshot(browser, url) if @options[:take_screenshots]
        page_content = browser.body
        log_message("Page loaded: #{url}")

        suggestions = analyze_with_gpt(url, page_content, screenshot_path)

        process_and_save_content(url, page_content, suggestions) if valid_content?(suggestions, page_content)
      else
        log_message("JavaScript content did not fully load for #{url}", level: :warn)
      end
    end
  rescue => e
    log_error_and_return("Error during scraping process for #{url}: #{e.message}", error: e)
  ensure
    cleanup_resources(browser)
  end

  private

  def initialize_logger
    Logger.new(STDOUT).tap do |log|
      log.level = @options[:log_level]
      log.formatter = proc { |severity, datetime, _, msg| "#{datetime.utc.iso8601} #{severity}: #{msg}
" }
    end
  end

  def log_message(message, level: :info)
    logger.public_send(level, message)
  rescue StandardError => e
    logger.error("Logging error: #{e.message}")
  end

  def log_error_and_return(error_message, error: nil)
    log_message("#{error_message}. Stack trace: #{error&.backtrace&.join("
")}", level: :error)
    nil
  end

  def initialize_browser
    Ferrum::Browser.new(
      timeout: @options[:timeout],
      process_timeout: @options[:process_timeout],
      browser_path: @options[:browser_path],
      headless: true,
      xvfb: @options[:xvfb],
      unveil: @options[:unveil]
    )
  rescue StandardError => e
    log_error_and_return("Browser initialization error: #{e.message}", error: e)
  end

  def wait_for_js(browser)
    log_message("Waiting for JavaScript to finish loading...")
    start_time = Time.now

    while Time.now - start_time < @options[:js_wait_time]
      return true if browser.evaluate("document.readyState") == "complete"
      sleep 1
    end

    log_message("JavaScript content did not fully load within the expected time.")
    false
  end

  def take_screenshot(browser, url)
    screenshot_path = "#{sanitize_filename(url)}.png"
    browser.screenshot(path: screenshot_path)
    log_message("Screenshot saved: #{screenshot_path}")
    screenshot_path
  end

  def analyze_with_gpt(url, page_content, screenshot_path)
    gpt_prompt = generate_gpt_prompt(url, page_content, screenshot_path)
    @llm.chat(messages: [{ role: "user", content: gpt_prompt }]).dig("choices", 0, "text")
  end

  def process_and_save_content(url, page_content, suggestions)
    markdown_content = Kramdown::Document.new(page_content).to_kramdown
    save_content(url, markdown_content, suggestions)
  end

  def save_content(url, markdown_content, suggestions)
    markdown_file = "#{sanitize_filename(url)}.md"
    save_if_changed(markdown_file, markdown_content)
    suggestions_file = "#{sanitize_filename(url)}_gpt_suggestions.txt"
    save_if_changed(suggestions_file, suggestions)
  end

  def save_if_changed(file_path, content)
    return false unless content_has_changed?(file_path, content)

    File.write(file_path, content)
    log_message("Content saved to: #{file_path}")
    true
  rescue => e
    log_error_and_return("Error saving content to #{file_path}: #{e.message}", error: e)
  end

  def content_has_changed?(file_path, new_content)
    !File.exist?(file_path) || Digest::SHA256.hexdigest(File.read(file_path)) != Digest::SHA256.hexdigest(new_content)
  end

  def cleanup_resources(browser)
    browser&.quit
    log_message("Cleaned up resources and closed browser.")
  end

  def sanitize_filename(url)
    url.gsub(%r{https?://}, "").gsub(/[^0-9A-Za-z.\-]/, "_")[0...255]
  end

  def generate_gpt_prompt(url, page_content, screenshot_path)
    <<~PROMPT
      I have scraped the following web page: #{url}. Here is the page content and a screenshot (#{screenshot_path}).
      Please analyze the content and suggest the most relevant sections or elements that should be scraped for documentation purposes.
      The content may include JavaScript-loaded elements or complex, nested structures. Focus on key sections, headings, or elements based on the content:
      #{page_content}
    PROMPT
  end

  def valid_content?(gpt_suggestions, page_content)
    valid = gpt_suggestions.include?("important section") && page_content.length > @options[:validation_min_length]
    if valid
      log_message("Content validation passed.")
    else
      log_message("Content validation failed.", level: :warn)
    end
    valid
  end

  def humanize(browser)
    delay = rand(2..8)
    log_message("Sleeping #{delay} seconds...")
    sleep delay
    browser.mouse.move(x: rand(0..1024), y: rand(0..768))
  rescue Ferrum::TimeoutError
    log_message("Timeout error during humanize interaction, rescuing...", level: :warn)
  end

  def retry_on_failure(times: 3)
    attempts = 0
    begin
      yield
    rescue => e
      attempts += 1
      log_message("Attempt #{attempts} failed with error: #{e.message}. Retrying...", level: :warn)
      retry if attempts < times
      log_error_and_return("Failed after #{times} attempts: #{e.message}", error: e)
    end
  end
end
