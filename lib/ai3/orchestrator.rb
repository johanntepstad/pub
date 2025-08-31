# frozen_string_literal: true

require "concurrent"
require "circuit_breaker"

module Ai3
  # Multi-LLM orchestration framework with round-robin load balancing,
  # context merging, session management, and circuit breaker patterns
  class Orchestrator
    include CircuitBreaker::Helpers

    MAX_SESSIONS = 10
    CONFIDENCE_THRESHOLD = 0.7
    TIMEOUT_SECONDS = 30

    attr_reader :providers, :sessions, :vector_db

    def initialize
      @providers = initialize_providers
      @sessions = Concurrent::Map.new
      @provider_index = Concurrent::AtomicFixnum.new(0)
      @vector_db = VectorDatabase.new
      @session_eviction = SessionEviction.new(max_size: MAX_SESSIONS)
    end

    # Main orchestration method with circuit breaker protection
    def process(prompt, session_id: nil, context: {})
      with_circuit_breaker("ai3_orchestration") do
        session = get_or_create_session(session_id)
        
        # Add context to session
        session.add_context(prompt, context)
        
        # Round-robin provider selection with health checks
        provider = select_healthy_provider
        
        # Process with timeout and error handling
        response = process_with_provider(provider, session)
        
        # Merge response with confidence scoring
        merged_response = merge_response(response, session)
        
        # Update vector database for future context
        @vector_db.store(prompt, merged_response, session_id)
        
        merged_response
      end
    rescue CircuitBreaker::OpenError => e
      fallback_response(prompt, session_id)
    rescue StandardError => e
      Rails.logger.error "AI3 Orchestration failed: #{e.message}"
      error_response(e)
    end

    # Health check for all providers
    def health_check
      results = {}
      @providers.each do |name, provider|
        results[name] = provider.healthy?
      end
      results
    end

    # Session management with LRU eviction
    def get_session(session_id)
      @sessions[session_id]
    end

    def clear_session(session_id)
      @sessions.delete(session_id)
      @vector_db.clear_session(session_id)
    end

    private

    def initialize_providers
      {
        xai_grok: Providers::XaiGrok.new,
        anthropic_claude: Providers::AnthropicClaude.new,
        openai_gpt: Providers::OpenaiGpt.new,
        ollama_local: Providers::OllamaLocal.new
      }
    end

    def get_or_create_session(session_id)
      return create_anonymous_session unless session_id

      session = @sessions[session_id]
      unless session
        # Evict old sessions if at capacity
        @session_eviction.make_room_if_needed(@sessions)
        
        session = Session.new(session_id)
        @sessions[session_id] = session
      end
      
      session.touch # Update last accessed time
      session
    end

    def create_anonymous_session
      Session.new(SecureRandom.uuid)
    end

    def select_healthy_provider
      # Round-robin selection with health checks
      attempts = 0
      max_attempts = @providers.size

      while attempts < max_attempts
        index = @provider_index.increment % @providers.size
        provider_name = @providers.keys[index]
        provider = @providers[provider_name]

        return provider if provider.healthy?
        
        attempts += 1
      end

      # Fallback to first provider if none are healthy
      @providers.values.first
    end

    def process_with_provider(provider, session)
      Timeout.timeout(TIMEOUT_SECONDS) do
        provider.process(
          session.merged_context,
          temperature: 0.7,
          max_tokens: 2000
        )
      end
    end

    def merge_response(response, session)
      # Advanced response merging with timestamp awareness
      merged = {
        content: response[:content],
        confidence: calculate_confidence(response, session),
        timestamp: Time.current.iso8601,
        provider: response[:provider],
        session_id: session.id,
        context_length: session.context_length
      }

      # Add confidence-based quality indicators
      if merged[:confidence] >= CONFIDENCE_THRESHOLD
        merged[:quality] = "high"
      elsif merged[:confidence] >= 0.5
        merged[:quality] = "medium"
      else
        merged[:quality] = "low"
        merged[:warning] = "Low confidence response, consider rephrasing"
      end

      merged
    end

    def calculate_confidence(response, session)
      # Confidence scoring based on response quality indicators
      base_confidence = response[:confidence] || 0.6
      
      # Adjust based on context length (more context = higher confidence)
      context_boost = [session.context_length / 1000.0, 0.2].min
      
      # Adjust based on response length and coherence
      length_factor = response[:content].length > 50 ? 0.1 : -0.1
      
      [base_confidence + context_boost + length_factor, 1.0].min
    end

    def fallback_response(prompt, session_id)
      # Simple fallback when circuit breaker is open
      {
        content: "AI services are temporarily unavailable. Please try again later.",
        confidence: 0.0,
        timestamp: Time.current.iso8601,
        provider: "fallback",
        session_id: session_id,
        quality: "fallback",
        warning: "Fallback response due to service unavailability"
      }
    end

    def error_response(error)
      {
        content: "An error occurred while processing your request.",
        confidence: 0.0,
        timestamp: Time.current.iso8601,
        provider: "error",
        quality: "error",
        error: error.message
      }
    end

    # Circuit breaker configuration
    def circuit_breaker_options
      {
        timeout: 5,
        threshold: 3,
        reenable_after: 30
      }
    end
  end
end