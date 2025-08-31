require "open-uri"
require "fileutils"
require "kramdown"
require "ferrum"
require "async"
require "zip"
require "logger"

# Configuration
TIMEOUT = 30
PROCESS_TIMEOUT = 60
OUTPUT_DIR = "__docs"
REPO_DIR = File.join(OUTPUT_DIR, "repos")
FileUtils.mkdir_p(REPO_DIR)

logger = Logger.new(STDOUT)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.utc.iso8601} #{severity}: #{msg}\n"
end

# URLs to scrape with their respective depths
web_urls = {
  "rails_edge_guides" => { url: "https://edgeguides.rubyonrails.org/", depth: 2 },
  "turbo" => { url: "https://turbo.hotwired.dev/handbook/introduction", depth: 2 },
  "stimulus" => { url: "https://stimulus.hotwired.dev/handbook", depth: 2 },
  "stimulus_reflex" => { url: "https://docs.stimulusreflex.com/", depth: 2 },
  "stimulus_components" => { url: "https://stimulus-components.com/docs/", depth: 2 },
  "stimulus_reflex_patterns" => { url: "https://stimulusreflexpatterns.com/patterns/", depth: 2 },
  "devise" => { url: "https://github.com/heartcombo/devise/wiki/How-Tos", depth: 2 },
  "replicate_docs" => { url: "https://replicate.com/docs", depth: 2 },
  "replicate_explore" => { url: "https://replicate.com/explore", depth: 2 },
  "nngroup" => { url: "https://nngroup.com/articles/", depth: 2 },
  "solidus_guides" => { url: "https://guides.solidus.io/", depth: 2 },
  "solidus_integrations" => { url: "https://solidus.io/integrations", depth: 2 },
  "solidus_global_commerce" => { url: "https://solidus.io/use-cases/global-commerce", depth: 2 },
  "solidus_subscriptions" => { url: "https://solidus.io/use-cases/subscriptions", depth: 2 },
  "solidus_marketplaces" => { url: "https://solidus.io/use-cases/marketplaces", depth: 2 }
}

# Repository URLs to download (no extraction for these)
repo_urls = {
  "langchainrb" => "https://github.com/patterns-ai-core/langchainrb/archive/refs/heads/main.zip",
  "langchainrb_rails" => "https://github.com/patterns-ai-core/langchainrb_rails/archive/refs/heads/main.zip",
  "ruby_openai" => "https://github.com/alexrudall/ruby-openai/archive/refs/heads/main.zip",
  "replicate_ruby" => "https://github.com/dreamingtulpa/replicate-ruby/archive/refs/heads/main.zip",
  "devise_guests" => "https://github.com/cbeer/devise-guests/archive/refs/heads/master.zip",
  "solidus_starter_frontend" => "https://github.com/solidusio/solidus_starter_frontend/archive/refs/heads/main.zip",
  "ferrum" => "https://github.com/rubycdp/ferrum/archive/refs/heads/main.zip",
  "faker" => "https://github.com/faker-ruby/faker/archive/refs/heads/main.zip",
  "weaviate_ruby" => "https://github.com/patterns-ai-core/weaviate-ruby/archive/refs/heads/main.zip"
}

# Track already downloaded files
downloaded_files = []

# Function to download a file
def download_file(url, filename, logger, downloaded_files)
  return if downloaded_files.include?(filename)

  File.open(File.join(REPO_DIR, filename), "wb") do |file|
    file.write(URI.open(url).read)
  end
  downloaded_files << filename
  logger.info("Downloaded #{url} to #{filename}")
rescue StandardError => e
  logger.error("Error downloading #{url}: #{e.message}")
end

# Function to scrape a web page and save as Markdown
def scrape_web_page(url, site_name, output_dir, logger, depth, max_depth, visited_urls, domain)
  return if depth > max_depth || visited_urls.include?(url)

  logger.info("Scraping: #{url}")
  browser = Ferrum::Browser.new(
    timeout: TIMEOUT,
    process_timeout: PROCESS_TIMEOUT,
    browser_path: "/usr/local/chrome/chrome", # OpenBSD wrapper
    # browser_path: "/usr/local/bin/chrome", # Actual binary
    headless: true,
    xvfb: true, # Virtual Framebuffer for Xorg
    unveil: true
  )

  begin
    browser.goto(url)
    content = browser.body
    markdown_content = Kramdown::Document.new(content).to_html
    site_dir = File.join(output_dir, site_name)
    FileUtils.mkdir_p(site_dir)
    file_name = File.join(site_dir, "#{sanitize_filename(url)}.md")
    File.write(file_name, markdown_content)
    logger.info("Saved to: #{file_name}")

    visited_urls << url
    links = browser.evaluate("Array.from(document.querySelectorAll('a')).map(a => a.href)")
    links.each do |link|
      begin
        link_domain = URI.parse(link).host
        if link_domain && link_domain.include?(domain)
          # Concurrently scrape the linked pages
          Async do
            scrape_web_page(link, site_name, output_dir, logger, depth + 1, max_depth, visited_urls, domain)
          end
          sleep(rand(1..3)) # Random delay to avoid hammering
        end
      rescue URI::InvalidURIError
        logger.error("Invalid URL: #{link}")
      end
    end
  rescue Ferrum::TimeoutError => e
    logger.error("Timed out waiting for response: #{e.message}")
  rescue StandardError => e
    logger.error("Error: #{e.message}")
  ensure
    browser.quit
  end
end

# Function to sanitize filenames
def sanitize_filename(url)
  url.gsub(%r{https?://}, '').gsub(/[^0-9A-Za-z.\-]/, '_')
end

# Function to clean up non-Markdown files and dotfiles from site folders
def clean_up_site_files(directory, logger)
  Dir.glob("#{directory}/**/*").each do |file|
    next if File.directory?(file) || file.end_with?(".md") || file.end_with?(".zip") || File.basename(file).start_with?(".")

    File.delete(file)
    logger.info("Deleted file: #{file}")
  rescue StandardError => e
    logger.error("Failed to delete file #{file}: #{e.message}")
  end
end

# Function to zip Markdown files from a site
def zip_site_files(site_name, source_dir, logger)
  zip_file = "#{site_name}.zip"
  zip_path = File.join(OUTPUT_DIR, zip_file)
  logger.info("Zipping Markdown files for site '#{site_name}' into: #{zip_path}")

  begin
    Zip::File.open(zip_path, Zip::File::CREATE) do |zip_file|
      Dir.glob("#{source_dir}/#{site_name}/**/*.md").each do |file|
        zip_file.add(file.sub("#{source_dir}/", ''), file)
      end
    end
    logger.info("Zip file created: #{zip_path}")
  rescue StandardError => e
    logger.error("Failed to create zip file: #{e.message}")
  end
end

# Download repositories
repo_urls.each do |name, url|
  download_file(url, "#{name}.zip", logger, downloaded_files)
end

# Scrape web pages
Async do
  web_urls.each do |name, details|
    Async do
      domain = URI.parse(details[:url]).host
      scrape_web_page(details[:url], name, OUTPUT_DIR, logger, 1, details[:depth], [], domain)
    end
    sleep(rand(1..3)) # Random delay to avoid hammering
  end
end.wait

# Clean up non-Markdown files and zip site folders
web_urls.each_key do |site_name|
  site_dir = File.join(OUTPUT_DIR, site_name)
  clean_up_site_files(site_dir, logger)
  zip_site_files(site_name, OUTPUT_DIR, logger)
end

logger.info("All downloads and scrapes complete.")

