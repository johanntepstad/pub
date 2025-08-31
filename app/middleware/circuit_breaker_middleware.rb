# frozen_string_literal: true

# Circuit breaker middleware with 3-failure threshold and exponential backoff
class CircuitBreakerMiddleware
  include Singleton

  FAILURE_THRESHOLD = 3
  TIMEOUT_SECONDS = 30
  RETRY_TIMEOUT_SECONDS = 60

  def initialize(app = nil)
    @app = app
    @circuit_breakers = Concurrent::Map.new
    @failure_counts = Concurrent::Map.new
    @last_failure_times = Concurrent::Map.new
    @timeouts = Concurrent::Map.new
  end

  def call(env)
    request = Rack::Request.new(env)
    circuit_key = generate_circuit_key(request)

    if circuit_open?(circuit_key)
      return circuit_breaker_response
    end

    begin
      Timeout.timeout(TIMEOUT_SECONDS) do
        response = @app.call(env)
        record_success(circuit_key) if response[0] < 500
        response
      end
    rescue Timeout::Error => e
      record_failure(circuit_key, "timeout")
      timeout_response
    rescue StandardError => e
      record_failure(circuit_key, e.class.name)
      error_response(e)
    end
  end

  private

  def generate_circuit_key(request)
    # Create circuit breaker key based on endpoint and method
    "#{request.request_method}:#{request.path_info}"
  end

  def circuit_open?(circuit_key)
    failure_count = @failure_counts[circuit_key] || 0
    return false if failure_count < FAILURE_THRESHOLD

    last_failure = @last_failure_times[circuit_key]
    return false unless last_failure

    # Check if we should attempt to close the circuit
    Time.current - last_failure < current_timeout(circuit_key)
  end

  def record_success(circuit_key)
    @failure_counts[circuit_key] = 0
    @timeouts[circuit_key] = RETRY_TIMEOUT_SECONDS
    @circuit_breakers[circuit_key] = :closed
  end

  def record_failure(circuit_key, error_type)
    @failure_counts[circuit_key] = (@failure_counts[circuit_key] || 0) + 1
    @last_failure_times[circuit_key] = Time.current
    
    # Exponential backoff
    current_timeout_value = @timeouts[circuit_key] || RETRY_TIMEOUT_SECONDS
    @timeouts[circuit_key] = [current_timeout_value * 2, 300].min # Max 5 minutes
    
    if @failure_counts[circuit_key] >= FAILURE_THRESHOLD
      @circuit_breakers[circuit_key] = :open
      Rails.logger.warn "Circuit breaker opened for #{circuit_key}: #{error_type}"
    end
  end

  def current_timeout(circuit_key)
    @timeouts[circuit_key] || RETRY_TIMEOUT_SECONDS
  end

  def circuit_breaker_response
    [
      503,
      {
        "Content-Type" => "application/json",
        "Retry-After" => "60",
        "X-Circuit-Breaker" => "open"
      },
      [JSON.generate({
        error: "Service temporarily unavailable",
        message: "Circuit breaker is open. Please try again later.",
        retry_after: 60
      })]
    ]
  end

  def timeout_response
    [
      504,
      {
        "Content-Type" => "application/json",
        "X-Timeout" => "true"
      },
      [JSON.generate({
        error: "Request timeout",
        message: "Request exceeded 30 second timeout limit"
      })]
    ]
  end

  def error_response(error)
    [
      500,
      {
        "Content-Type" => "application/json",
        "X-Error-Type" => error.class.name
      },
      [JSON.generate({
        error: "Internal server error",
        message: "An unexpected error occurred"
      })]
    ]
  end

  # Class method for manual circuit breaker operations
  def self.instance
    @instance ||= new
  end

  def self.force_open(circuit_key)
    instance.instance_variable_get(:@circuit_breakers)[circuit_key] = :open
    instance.instance_variable_get(:@failure_counts)[circuit_key] = FAILURE_THRESHOLD
    instance.instance_variable_get(:@last_failure_times)[circuit_key] = Time.current
  end

  def self.force_close(circuit_key)
    instance.instance_variable_get(:@circuit_breakers)[circuit_key] = :closed
    instance.instance_variable_get(:@failure_counts)[circuit_key] = 0
  end

  def self.circuit_status
    breakers = instance.instance_variable_get(:@circuit_breakers)
    failures = instance.instance_variable_get(:@failure_counts)
    
    result = {}
    breakers.each do |key, status|
      result[key] = {
        status: status,
        failure_count: failures[key] || 0,
        last_failure: instance.instance_variable_get(:@last_failure_times)[key]
      }
    end
    result
  end
end