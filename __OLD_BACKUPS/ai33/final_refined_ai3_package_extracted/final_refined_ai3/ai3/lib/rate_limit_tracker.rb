
# encoding: utf-8
# Rate limit tracker for managing API usage

class RateLimitTracker
  def initialize(limit_per_minute:, cost_per_token:)
    @limit_per_minute = limit_per_minute
    @cost_per_token = cost_per_token
    @used_tokens = 0
    @start_time = Time.now
  end

  def track_usage(tokens)
    if tokens + @used_tokens > @limit_per_minute
      raise "Rate limit exceeded"
    else
      @used_tokens += tokens
      @cost = tokens * @cost_per_token
      log_usage(tokens, @cost)
    end
  end

  def reset_limit
    @used_tokens = 0
    @start_time = Time.now
  end

  private

  def log_usage(tokens, cost)
    puts "[INFO] Used #{tokens} tokens. Cost: $#{cost.round(2)}."
  end

  def time_since_start
    Time.now - @start_time
  end
end
