# frozen_string_literal: true

module Ai3
  module Providers
    # Base provider class with common functionality
    class BaseProvider
      attr_reader :name, :last_health_check, :healthy

      def initialize(name)
        @name = name
        @last_health_check = Time.current
        @healthy = true
        @consecutive_failures = 0
        @max_failures = 3
      end

      def process(context, **options)
        raise NotImplementedError, "Subclasses must implement process method"
      end

      def healthy?
        # Check if we need to update health status
        if @last_health_check < 30.seconds.ago
          update_health_status
        end
        
        @healthy && @consecutive_failures < @max_failures
      end

      protected

      def record_success
        @consecutive_failures = 0
        @healthy = true
      end

      def record_failure
        @consecutive_failures += 1
        @healthy = false if @consecutive_failures >= @max_failures
      end

      def update_health_status
        @last_health_check = Time.current
        # Default implementation - subclasses can override
        @healthy = true
      end

      def make_request(endpoint, payload)
        raise NotImplementedError, "Subclasses must implement make_request method"
      end
    end

    # xAI Grok provider
    class XaiGrok < BaseProvider
      def initialize
        super("xai_grok")
        @api_key = Rails.application.credentials.xai_api_key
        @base_url = "https://api.x.ai/v1"
      end

      def process(context, temperature: 0.7, max_tokens: 2000)
        payload = {
          model: "grok-beta",
          messages: [
            {
              role: "system",
              content: "You are Grok, a helpful AI assistant focused on healthcare policy analysis."
            },
            {
              role: "user",
              content: context
            }
          ],
          temperature: temperature,
          max_tokens: max_tokens
        }

        response = make_request("/chat/completions", payload)
        
        if response && response["choices"]&.any?
          record_success
          {
            content: response["choices"][0]["message"]["content"],
            provider: @name,
            confidence: 0.8,
            model: "grok-beta"
          }
        else
          record_failure
          raise "Invalid response from xAI Grok"
        end
      rescue StandardError => e
        record_failure
        Rails.logger.error "xAI Grok error: #{e.message}"
        raise e
      end

      private

      def make_request(endpoint, payload)
        return nil unless @api_key

        uri = URI("#{@base_url}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = http.request(request)
        JSON.parse(response.body) if response.code == "200"
      end

      def update_health_status
        super
        begin
          # Simple health check
          test_payload = {
            model: "grok-beta",
            messages: [{ role: "user", content: "Health check" }],
            max_tokens: 10
          }
          
          response = make_request("/chat/completions", test_payload)
          @healthy = !response.nil?
        rescue StandardError
          @healthy = false
        end
      end
    end

    # Anthropic Claude provider
    class AnthropicClaude < BaseProvider
      def initialize
        super("anthropic_claude")
        @api_key = Rails.application.credentials.anthropic_api_key
        @base_url = "https://api.anthropic.com/v1"
      end

      def process(context, temperature: 0.7, max_tokens: 2000)
        payload = {
          model: "claude-3-sonnet-20240229",
          messages: [
            {
              role: "user",
              content: context
            }
          ],
          temperature: temperature,
          max_tokens: max_tokens
        }

        response = make_request("/messages", payload)
        
        if response && response["content"]&.any?
          record_success
          {
            content: response["content"][0]["text"],
            provider: @name,
            confidence: 0.85,
            model: "claude-3-sonnet"
          }
        else
          record_failure
          raise "Invalid response from Anthropic Claude"
        end
      rescue StandardError => e
        record_failure
        Rails.logger.error "Anthropic Claude error: #{e.message}"
        raise e
      end

      private

      def make_request(endpoint, payload)
        return nil unless @api_key

        uri = URI("#{@base_url}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        request["x-api-key"] = @api_key
        request["anthropic-version"] = "2023-06-01"
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = http.request(request)
        JSON.parse(response.body) if response.code == "200"
      end
    end

    # OpenAI GPT provider
    class OpenaiGpt < BaseProvider
      def initialize
        super("openai_gpt")
        @api_key = Rails.application.credentials.openai_api_key
        @base_url = "https://api.openai.com/v1"
      end

      def process(context, temperature: 0.7, max_tokens: 2000)
        payload = {
          model: "gpt-4",
          messages: [
            {
              role: "system",
              content: "You are a helpful AI assistant focused on healthcare policy analysis."
            },
            {
              role: "user",
              content: context
            }
          ],
          temperature: temperature,
          max_tokens: max_tokens
        }

        response = make_request("/chat/completions", payload)
        
        if response && response["choices"]&.any?
          record_success
          {
            content: response["choices"][0]["message"]["content"],
            provider: @name,
            confidence: 0.9,
            model: "gpt-4"
          }
        else
          record_failure
          raise "Invalid response from OpenAI GPT"
        end
      rescue StandardError => e
        record_failure
        Rails.logger.error "OpenAI GPT error: #{e.message}"
        raise e
      end

      private

      def make_request(endpoint, payload)
        return nil unless @api_key

        uri = URI("#{@base_url}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = http.request(request)
        JSON.parse(response.body) if response.code == "200"
      end
    end

    # Ollama local provider
    class OllamaLocal < BaseProvider
      def initialize
        super("ollama_local")
        @base_url = ENV.fetch("OLLAMA_URL", "http://localhost:11434")
        @model = ENV.fetch("OLLAMA_MODEL", "llama2")
      end

      def process(context, temperature: 0.7, max_tokens: 2000)
        payload = {
          model: @model,
          prompt: context,
          options: {
            temperature: temperature,
            num_predict: max_tokens
          }
        }

        response = make_request("/api/generate", payload)
        
        if response && response["response"]
          record_success
          {
            content: response["response"],
            provider: @name,
            confidence: 0.7,
            model: @model
          }
        else
          record_failure
          raise "Invalid response from Ollama"
        end
      rescue StandardError => e
        record_failure
        Rails.logger.error "Ollama error: #{e.message}"
        raise e
      end

      private

      def make_request(endpoint, payload)
        uri = URI("#{@base_url}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = http.request(request)
        JSON.parse(response.body) if response.code == "200"
      rescue StandardError
        nil
      end

      def update_health_status
        super
        begin
          # Check if Ollama is running
          uri = URI("#{@base_url}/api/tags")
          http = Net::HTTP.new(uri.host, uri.port)
          response = http.get(uri.path)
          @healthy = response.code == "200"
        rescue StandardError
          @healthy = false
        end
      end
    end
  end
end