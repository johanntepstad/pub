require 'ferrum'
require 'base64'
require_relative 'langchain_wrapper'

class VisualScraper
  # Expanded and diverse user agents list for better simulation
  USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15",
    "Mozilla/5.0 (iPad; CPU OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.92 Mobile Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:68.0) Gecko/20100101 Firefox/68.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36",
    # More user agents can be added here
  ]

  def initialize(target_url, langchain_wrapper)
    @langchain_wrapper = langchain_wrapper
    options = {
      browser_options: { 'user-agent': select_user_agent }
    }
    @browser = Ferrum::Browser.new(**options)
    @page = @browser.create_page
    @page.go_to(target_url)
    simulate_human_browsing
  end

  def simulate_human_browsing
    sleep rand(1..3)
    @page.mouse.move(x: rand(100..200), y: rand(100..200))
    random_scroll
  end

  def random_scroll
    3.times do
      @page.mouse.scroll_to(rand(0..100), rand(0..200))
      sleep rand(1..2)
    end
  end

  def take_screenshot
    screenshot_data = @page.screenshot(full: true)
    Base64.strict_encode64(screenshot_data)
  end

  def analyze_page
    image_base64 = take_screenshot
    prompt = "Analyze this page's layout and content."
    analysis = @langchain_wrapper.analyze_with_gpt_vision(image_base64)
    puts "Page Analysis: #{analysis}"
  end

  private

  def select_user_agent
    USER_AGENTS.sample
  end

  def close
    @browser.quit
  end
end

