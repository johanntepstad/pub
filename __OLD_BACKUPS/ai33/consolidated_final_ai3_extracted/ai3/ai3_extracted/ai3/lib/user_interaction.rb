# encoding: utf-8

# User interaction handler with sentiment analysis and intent recognition

require 'langchainrb'

class UserInteraction
  def initialize(rag_system)
    @rag_system = rag_system
  end

  def handle_interaction(user_input)
    sentiment = analyze_sentiment(user_input)
    intent = detect_intent(user_input)
    response = generate_response(user_input, sentiment, intent)
    response
  end

  private

  def analyze_sentiment(text)
    with_error_handling do
      sentiment_response = @rag_system.generate_response("Analyze the sentiment: #{text}")
      sentiment_response
    end
  end

  def detect_intent(text)
    with_error_handling do
      intent_response = @rag_system.generate_response("Detect the intent: #{text}")
      intent_response
    end
  end

  def generate_response(user_input, sentiment, intent)
    with_error_handling do
      response = @rag_system.generate_response("Based on the sentiment (#{sentiment}) and intent (#{intent}), generate a response to: #{user_input}")
      response
    end
  end

  def with_error_handling
    yield
  rescue => e
    ErrorHandler.handle(e, context: { user_input: user_input })
    "Error: Could not process the user input."
  end
end
