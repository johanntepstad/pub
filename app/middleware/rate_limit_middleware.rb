# frozen_string_literal: true

# Rate limiting middleware with token bucket algorithm
class RateLimitMiddleware
  include Singleton

  # Rate limits per endpoint type
  RATE_LIMITS = {
    "/api/ai3/" => { requests: 10, window: 60 }, # AI requests
    "/api/payment/" => { requests: 5, window: 60 }, # Payment requests  
    "/api/health/" => { requests: 20, window: 60 }, # Health data
    "/api/" => { requests: 100, window: 60 }, # General API
    "/" => { requests: 1000, window: 60 } # Web requests
  }.freeze

  GLOBAL_LIMIT = { requests: 10000, window: 60 }
  MEMORY_LIMIT_MB = 512
  CPU_LIMIT_PERCENT = 80

  def initialize(app = nil)
    @app = app
    @buckets = Concurrent::Map.new
    @global_bucket = TokenBucket.new(GLOBAL_LIMIT[:requests], GLOBAL_LIMIT[:window])
    @memory_monitor = MemoryMonitor.new
    @cpu_monitor = CpuMonitor.new
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Check system resources first
    return resource_limit_response("memory") if memory_exceeded?
    return resource_limit_response("cpu") if cpu_exceeded?

    # Apply rate limiting
    client_id = extract_client_id(request)
    endpoint_pattern = match_endpoint_pattern(request.path_info)
    
    # Check global rate limit
    return rate_limit_response("global") unless @global_bucket.consume(1)
    
    # Check endpoint-specific rate limit
    bucket = get_or_create_bucket(client_id, endpoint_pattern)
    return rate_limit_response("endpoint") unless bucket.consume(1)

    # Add rate limit headers to response
    response = @app.call(env)
    add_rate_limit_headers(response, bucket, endpoint_pattern)
    response
  end

  private

  def extract_client_id(request)
    # Priority order for client identification
    client_id = request.env["HTTP_X_API_KEY"] ||
                request.env["HTTP_AUTHORIZATION"]&.split(" ")&.last ||
                request.session[:user_id] ||
                request.ip

    # Hash for privacy if it's an IP
    if client_id == request.ip
      Digest::SHA256.hexdigest("#{client_id}:#{Date.current}")
    else
      client_id
    end
  end

  def match_endpoint_pattern(path)
    RATE_LIMITS.keys.find { |pattern| path.start_with?(pattern) } || "/"
  end

  def get_or_create_bucket(client_id, endpoint_pattern)
    bucket_key = "#{client_id}:#{endpoint_pattern}"
    
    @buckets[bucket_key] ||= begin
      limit_config = RATE_LIMITS[endpoint_pattern]
      TokenBucket.new(limit_config[:requests], limit_config[:window])
    end
  end

  def memory_exceeded?
    @memory_monitor.current_usage_mb > MEMORY_LIMIT_MB
  end

  def cpu_exceeded?
    @cpu_monitor.current_usage_percent > CPU_LIMIT_PERCENT
  end

  def rate_limit_response(limit_type)
    retry_after = case limit_type
                  when "global"
                    @global_bucket.reset_time
                  when "endpoint"
                    60
                  else
                    60
                  end

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s,
        "X-RateLimit-Limit-Type" => limit_type
      },
      [JSON.generate({
        error: "Rate limit exceeded",
        message: "Too many requests. Please try again later.",
        limit_type: limit_type,
        retry_after: retry_after
      })]
    ]
  end

  def resource_limit_response(resource_type)
    [
      503,
      {
        "Content-Type" => "application/json",
        "Retry-After" => "30",
        "X-Resource-Limit" => resource_type
      },
      [JSON.generate({
        error: "Resource limit exceeded",
        message: "Server is currently under high load. Please try again later.",
        resource_type: resource_type,
        retry_after: 30
      })]
    ]
  end

  def add_rate_limit_headers(response, bucket, endpoint_pattern)
    limit_config = RATE_LIMITS[endpoint_pattern]
    
    response[1].merge!({
      "X-RateLimit-Limit" => limit_config[:requests].to_s,
      "X-RateLimit-Remaining" => bucket.tokens.to_s,
      "X-RateLimit-Reset" => bucket.reset_time.to_s,
      "X-RateLimit-Window" => limit_config[:window].to_s
    })
  end

  # Token bucket implementation
  class TokenBucket
    attr_reader :capacity, :tokens, :window

    def initialize(capacity, window_seconds)
      @capacity = capacity
      @window = window_seconds
      @tokens = capacity
      @last_refill = Time.current
      @mutex = Mutex.new
    end

    def consume(tokens_requested = 1)
      @mutex.synchronize do
        refill_if_needed
        
        if @tokens >= tokens_requested
          @tokens -= tokens_requested
          true
        else
          false
        end
      end
    end

    def reset_time
      Time.current.to_i + @window
    end

    private

    def refill_if_needed
      now = Time.current
      time_passed = now - @last_refill
      
      if time_passed >= @window
        @tokens = @capacity
        @last_refill = now
      else
        # Gradual refill based on time passed
        tokens_to_add = (@capacity * time_passed / @window).floor
        @tokens = [@tokens + tokens_to_add, @capacity].min
        @last_refill = now if tokens_to_add > 0
      end
    end
  end

  # Memory monitoring
  class MemoryMonitor
    def current_usage_mb
      # Get RSS memory usage
      if File.exist?("/proc/self/status")
        status = File.read("/proc/self/status")
        if match = status.match(/VmRSS:\s*(\d+)\s*kB/)
          match[1].to_f / 1024.0 # Convert kB to MB
        else
          0
        end
      else
        # Fallback for non-Linux systems
        `ps -o rss= -p #{Process.pid}`.to_f / 1024.0
      end
    rescue StandardError
      0
    end
  end

  # CPU monitoring
  class CpuMonitor
    def initialize
      @last_check = Time.current
      @last_cpu_time = Process.times.utime + Process.times.stime
    end

    def current_usage_percent
      now = Time.current
      current_cpu_time = Process.times.utime + Process.times.stime
      
      time_diff = now - @last_check
      cpu_diff = current_cpu_time - @last_cpu_time
      
      usage = time_diff > 0 ? (cpu_diff / time_diff) * 100 : 0
      
      @last_check = now
      @last_cpu_time = current_cpu_time
      
      [usage, 100].min
    rescue StandardError
      0
    end
  end

  # Class methods for monitoring
  def self.instance
    @instance ||= new
  end

  def self.current_limits
    buckets = instance.instance_variable_get(:@buckets)
    
    result = {
      global: {
        tokens: instance.instance_variable_get(:@global_bucket).tokens,
        capacity: GLOBAL_LIMIT[:requests]
      },
      memory_usage_mb: instance.instance_variable_get(:@memory_monitor).current_usage_mb,
      cpu_usage_percent: instance.instance_variable_get(:@cpu_monitor).current_usage_percent,
      active_buckets: buckets.size
    }

    buckets.each do |key, bucket|
      result[:buckets] ||= {}
      result[:buckets][key] = {
        tokens: bucket.tokens,
        capacity: bucket.capacity
      }
    end

    result
  end

  def self.reset_client_limits(client_id)
    buckets = instance.instance_variable_get(:@buckets)
    buckets.keys.select { |key| key.start_with?("#{client_id}:") }.each do |key|
      buckets.delete(key)
    end
  end

  def self.health_check
    monitor = instance
    memory_usage = monitor.instance_variable_get(:@memory_monitor).current_usage_mb
    cpu_usage = monitor.instance_variable_get(:@cpu_monitor).current_usage_percent
    
    {
      status: memory_usage < MEMORY_LIMIT_MB && cpu_usage < CPU_LIMIT_PERCENT ? "healthy" : "degraded",
      memory: {
        current_mb: memory_usage,
        limit_mb: MEMORY_LIMIT_MB,
        usage_percent: (memory_usage / MEMORY_LIMIT_MB * 100).round(2)
      },
      cpu: {
        current_percent: cpu_usage,
        limit_percent: CPU_LIMIT_PERCENT
      },
      rate_limits: RATE_LIMITS
    }
  end
end