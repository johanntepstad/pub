
# encoding: utf-8
# Universal scraper for context-aware data scraping

require 'nokogiri'
require 'open-uri'
require_relative 'error_handling'
require_relative 'rag_system'

class UniversalScraper
  def initialize(rag_system)
    @rag_system = rag_system
  end

  def scrape(url)
    with_error_handling do
      document = Nokogiri::HTML(URI.open(url))
      context = document.css('body').text.strip
      refined_context = @rag_system.generate_response("Refine the following scraped content: #{context}")
      refined_context
    end
  rescue => e
    ErrorHandler.handle(e, context: { url: url })
    "Error: Could not scrape the URL."
  end

  private

  def with_error_handling
    yield
  rescue => e
    ErrorHandler.handle(e)
  end
end
