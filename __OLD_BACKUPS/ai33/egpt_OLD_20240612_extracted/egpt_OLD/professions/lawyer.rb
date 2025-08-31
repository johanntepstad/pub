module Professions
  class LawyerAssistant
    LAW_DATABASE_URLS = ["https://www.lovdata.no"]  # Norway's primary law database

    def initialize(language: 'en')
      @visual_scraper = VisualScraper.new
      @weaviate_integration = WeaviateIntegration.new
      @language = language
      ensure_data_prepared
    end

    def conduct_legal_consultation
      puts "Welcome to your legal consultation."
      ensure_data_prepared  # Makes sure all relevant data is indexed
      puts "How can I assist you with your legal concerns today?"
      while (input = gets.chomp.downcase) != 'exit'
        handle_specific_legal_question(input)
        puts "\nCan I help you with anything else? (Type 'exit' to end the consultation)"
      end
    end

    private

    def ensure_data_prepared
      LAW_DATABASE_URLS.each do |url|
        unless @weaviate_integration.check_if_indexed(url)
          data = @visual_scraper.analyze_content(url)
          @weaviate_integration.add_data_to_weaviate({url: url, content: data})
        end
      end
    end

    def scrape_and_index(url)
      puts "Indexing legal content from #{url}..."
      data = @visual_scraper.analyze_content(url)
      @weaviate_integration.add_data_to_weaviate(url: url, content: data)
    end

    def handle_specific_legal_question(question)
      puts "Analyzing your query: '#{question}'..."
      insights = @weaviate_integration.query_with_insights(question)
      if insights.empty?
        puts "I couldn't find specific information on that topic, let's try a different question."
      else
        puts "Based on similar cases, here's some advice:\n#{insights}"
      end
    end

    def questions
      ["describe_unfair_treatment", "mention_omissions", "list_potential_witnesses", "describe_evidence", "impact_on_you_and_child", "legal_strategy_preference", "financial_situation_overview"]
    end
  end
end


    private


