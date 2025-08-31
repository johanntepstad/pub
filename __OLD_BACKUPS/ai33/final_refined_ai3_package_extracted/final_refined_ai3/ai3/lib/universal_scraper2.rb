# universal_scraper.rb

# gem install --user-install nokogiri -- --use-system-libraries

require 'nokogiri'
require 'open-uri'
require 'kramdown'
require 'ferrum'
require 'logger'
require 'json'
require 'csv'

class UniversalScraper
  attr_reader :logger, :options

  USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.1.2 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:56.0) Gecko/20100101 Firefox/56.0",
    "Mozilla/5.0 (Linux; Android 7.0; SM-G930V Build/NRD90M) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.116 Mobile Safari/537.36"
  ]

  def initialize(options = {})
    raise "Missing OpenAI API key" unless ENV["OPENAI_API_KEY"]

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
      take_screenshots: true,
      language_filter: nil,
      output_format: :markdown,
      ethical_scraping: true,
      proxy_rotation: false,
      adaptive_learning: true,
      custom_rules: nil
    }.merge(options)

    @logger = initialize_logger
    @adaptive_log = [] # Stores patterns from past scrapes for learning
  end

  def scrape(url)
    validate_output_directory
    return unless ethical_check(url)

    load_adaptive_patterns if @options[:adaptive_learning]

    browser = nil
    with_error_handling do
      browser = initialize_browser
      browser.goto(url)

      page_content = browser.body
      refined_content = refine_content(url, page_content, browser)
      save_if_changed("#{sanitize_filename(url)}.md", refined_content)

      log_successful_scrape(url, page_content) if @options[:adaptive_learning]
    end
  rescue => e
    handle_scraping_error(e, url)
  ensure
    cleanup_resources(browser)
  end

  private

  def validate_output_directory
    unless File.writable?(OUTPUT_DIR)
      raise "Output directory is not writable: #{OUTPUT_DIR}"
    end
  end

  def initialize_logger
    Logger.new(STDOUT).tap do |log|
      log.level = @options[:log_level]
      log.formatter = proc { |severity, datetime, _, msg| "#{datetime.utc.iso8601} #{severity}: #{msg}\n" }
    end
  end

  def ethical_check(url)
    if @options[:ethical_scraping] && !respect_robots_txt(url)
      @logger.warn("Skipping #{url} due to robots.txt restrictions.")
      return false
    end
    true
  end

  def respect_robots_txt(url)
    robots_url = URI.join(url, "/robots.txt")
    begin
      robots_content = URI.open(robots_url).read
      disallowed_paths = robots_content.scan(/^Disallow: (.+)$/).flatten.map(&:strip)
      disallowed_paths.none? { |path| url.include?(path) }
    rescue
      @logger.warn("Could not retrieve robots.txt for #{url}. Proceeding with caution.")
      true
    end
  end

  def refine_content(url, page_content, browser)
    # Refinement process (simplified without RAG system)
    screenshot_path = take_screenshot(browser, url) if @options[:take_screenshots]
    prompt = generate_gpt_prompt(url, page_content, screenshot_path)
    refined_content = prompt # Simple pass-through for now, refine logic as needed
    apply_custom_rules(refined_content) if @options[:custom_rules] # Apply custom rules
    refined_content
  end

  def apply_custom_rules(content)
    @options[:custom_rules].each do |rule|
      content.gsub!(rule[:pattern], rule[:replacement]) if rule[:type] == :replace
    end
    content
  end

  def load_adaptive_patterns
    if File.exist?("adaptive_patterns.json")
      patterns = JSON.parse(File.read("adaptive_patterns.json"))
      @adaptive_log.concat(patterns)
    end
  end

  def log_successful_scrape(url, content)
    @adaptive_log << { url: url, content: Digest::SHA256.hexdigest(content) }
    File.write("adaptive_patterns.json", @adaptive_log.to_json)
  end

  def handle_scraping_error(error, url)
    @logger.error("Error scraping #{url}: #{error.message}")
    log_adaptive_error(url, error.message) if @options[:adaptive_learning]
  end

  def log_adaptive_error(url, error_message)
    @adaptive_log << { url: url, error: error_message }
    File.write("adaptive_errors.json", @adaptive_log.to_json)
  end

  def with_error_handling
    yield
  rescue => e
    handle_scraping_error(e, "General")
  end

  def initialize_browser
    Ferrum::Browser.new(
      timeout: @options[:timeout],
      process_timeout: @options[:process_timeout],
      browser_path: @options[:browser_path],
      headless: true,
      xvfb: @options[:xvfb],
      unveil: @options[:unveil],
      user_agent: USER_AGENTS.sample # Use a random user-agent to avoid detection
    )
  end

  def save_if_changed(file_path, content)
    return false unless content_has_changed?(file_path, content)

    File.write(file_path, content)
    @logger.info("Content saved to: #{file_path}")
    true
  rescue => e
    handle_scraping_error(e, file_path)
  end

  def content_has_changed?(file_path, new_content)
    !File.exist?(file_path) || Digest::SHA256.hexdigest(File.read(file_path)) != Digest::SHA256.hexdigest(new_content)
  end

  def cleanup_resources(browser)
    browser&.quit
    @logger.info("Cleaned up resources and closed browser.")
  end

  def sanitize_filename(url)
    url.gsub(%r{https?://}, "").gsub(/[^0-9A-Za-z.\-]/, "_")[0...255]
  end

  def generate_gpt_prompt(url, page_content, screenshot_path)
    <<~PROMPT
      You are analyzing the following web page: #{url}.
      Here is the page content and a screenshot (#{screenshot_path}).
      Please identify the most important sections to scrape, considering the presence of dynamic content, pagination, and nested structures.
      Focus on key sections, headings, or elements based on the content provided:
      #{page_content}
    PROMPT
  end

  def take_screenshot(browser, url)
    screenshot_path = "#{sanitize_filename(url)}.png"
    browser.screenshot(path: screenshot_path)
    @logger.info("Screenshot saved: #{screenshot_path}")
    screenshot_path
  end
end

