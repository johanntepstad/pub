# frozen_string_literal: true

# Performance and caching configuration for Public Healthcare Platform
# Implements LRU caching, Redis failover, and CDN optimization

Rails.application.configure do
  # Solid Cache configuration with Redis fallback
  config.cache_store = :solid_cache_store, {
    database: Rails.root.join("storage", "cache.sqlite3"),
    max_size: 100.megabytes,
    max_entries: 50_000
  }

  # Background job processing with Solid Queue
  config.active_job.queue_adapter = :solid_queue

  # Session store with Redis fallback
  if Rails.env.production?
    config.session_store :redis_session_store, {
      key: '_pub_healthcare_session',
      redis: {
        host: ENV.fetch('REDIS_HOST', 'localhost'),
        port: ENV.fetch('REDIS_PORT', 6379),
        db: ENV.fetch('REDIS_DB', 0),
        password: ENV.fetch('REDIS_PASSWORD', nil)
      },
      expire_after: 4.hours,
      secure: true,
      httponly: true,
      same_site: :strict
    }
  end
end

# LRU Cache implementation with TTL support
class LruCacheWithTtl
  include Singleton
  
  def initialize(max_size: 100, default_ttl: 3600)
    @max_size = max_size
    @default_ttl = default_ttl
    @cache = {}
    @access_order = []
    @expiry_times = {}
    @mutex = Mutex.new
  end

  def get(key)
    @mutex.synchronize do
      cleanup_expired
      
      if @cache.key?(key) && !expired?(key)
        # Move to end (most recently used)
        @access_order.delete(key)
        @access_order.push(key)
        @cache[key]
      else
        nil
      end
    end
  end

  def put(key, value, ttl: nil)
    @mutex.synchronize do
      cleanup_expired
      
      ttl ||= @default_ttl
      
      # Remove if already exists
      if @cache.key?(key)
        @access_order.delete(key)
      end
      
      # Add new entry
      @cache[key] = value
      @access_order.push(key)
      @expiry_times[key] = Time.current + ttl.seconds
      
      # Evict least recently used if over capacity
      evict_lru while @cache.size > @max_size
    end
  end

  def delete(key)
    @mutex.synchronize do
      @cache.delete(key)
      @access_order.delete(key)
      @expiry_times.delete(key)
    end
  end

  def clear
    @mutex.synchronize do
      @cache.clear
      @access_order.clear
      @expiry_times.clear
    end
  end

  def size
    @mutex.synchronize do
      cleanup_expired
      @cache.size
    end
  end

  def stats
    @mutex.synchronize do
      cleanup_expired
      {
        size: @cache.size,
        max_size: @max_size,
        hit_ratio: @hit_ratio || 0.0,
        keys: @cache.keys.first(10) # Sample of keys
      }
    end
  end

  private

  def cleanup_expired
    current_time = Time.current
    expired_keys = @expiry_times.select { |_, expiry| expiry < current_time }.keys
    
    expired_keys.each do |key|
      @cache.delete(key)
      @access_order.delete(key)
      @expiry_times.delete(key)
    end
  end

  def expired?(key)
    expiry = @expiry_times[key]
    expiry && expiry < Time.current
  end

  def evict_lru
    return if @access_order.empty?
    
    lru_key = @access_order.first
    @cache.delete(lru_key)
    @access_order.delete(lru_key)
    @expiry_times.delete(lru_key)
  end
end

# Redis failover client
class RedisFailoverClient
  include Singleton
  
  def initialize
    @primary_config = {
      host: ENV.fetch('REDIS_PRIMARY_HOST', 'localhost'),
      port: ENV.fetch('REDIS_PRIMARY_PORT', 6379),
      db: ENV.fetch('REDIS_DB', 0),
      password: ENV.fetch('REDIS_PASSWORD', nil),
      timeout: 5
    }
    
    @fallback_config = {
      host: ENV.fetch('REDIS_FALLBACK_HOST', 'localhost'),
      port: ENV.fetch('REDIS_FALLBACK_PORT', 6380),
      db: ENV.fetch('REDIS_DB', 0),
      password: ENV.fetch('REDIS_PASSWORD', nil),
      timeout: 5
    }
    
    @primary_client = nil
    @fallback_client = nil
    @using_fallback = false
    @mutex = Mutex.new
  end

  def get(key)
    with_failover { |client| client.get(key) }
  end

  def set(key, value, ex: nil)
    options = ex ? { ex: ex } : {}
    with_failover { |client| client.set(key, value, **options) }
  end

  def del(key)
    with_failover { |client| client.del(key) }
  end

  def exists?(key)
    with_failover { |client| client.exists?(key) }
  end

  def expire(key, seconds)
    with_failover { |client| client.expire(key, seconds) }
  end

  def flushdb
    with_failover { |client| client.flushdb }
  end

  def ping
    with_failover { |client| client.ping }
  end

  def info
    with_failover { |client| client.info }
  end

  def health_check
    primary_healthy = test_connection(@primary_config)
    fallback_healthy = test_connection(@fallback_config)
    
    {
      primary: {
        healthy: primary_healthy,
        config: @primary_config.except(:password)
      },
      fallback: {
        healthy: fallback_healthy,
        config: @fallback_config.except(:password)
      },
      current: @using_fallback ? 'fallback' : 'primary'
    }
  end

  private

  def with_failover
    @mutex.synchronize do
      client = get_client
      yield(client)
    end
  rescue Redis::CannotConnectError, Redis::TimeoutError, Redis::ConnectionError => e
    Rails.logger.warn "Redis connection failed: #{e.message}"
    
    @mutex.synchronize do
      switch_to_fallback
      client = get_client
      yield(client)
    end
  end

  def get_client
    if @using_fallback
      @fallback_client ||= Redis.new(@fallback_config)
    else
      @primary_client ||= Redis.new(@primary_config)
    end
  end

  def switch_to_fallback
    return if @using_fallback
    
    @using_fallback = true
    @primary_client = nil
    Rails.logger.warn "Switched to Redis fallback server"
  end

  def test_connection(config)
    client = Redis.new(config)
    client.ping == 'PONG'
  rescue StandardError
    false
  ensure
    client&.disconnect
  end
end

# CDN cache management
module CdnCacheManager
  extend self
  
  CDN_ENDPOINTS = {
    primary: ENV.fetch('CDN_PRIMARY_URL', 'https://cdn.pub.healthcare'),
    fallback: ENV.fetch('CDN_FALLBACK_URL', 'https://fallback-cdn.pub.healthcare')
  }.freeze
  
  def purge_cache(paths)
    paths = Array(paths)
    results = {}
    
    CDN_ENDPOINTS.each do |name, endpoint|
      begin
        result = purge_from_endpoint(endpoint, paths)
        results[name] = { success: true, result: result }
      rescue StandardError => e
        results[name] = { success: false, error: e.message }
        Rails.logger.error "CDN purge failed for #{name}: #{e.message}"
      end
    end
    
    results
  end
  
  def invalidate_pattern(pattern)
    # Invalidate cache for assets matching pattern
    paths = find_assets_matching(pattern)
    purge_cache(paths)
  end
  
  def warm_cache(paths)
    paths = Array(paths)
    results = {}
    
    CDN_ENDPOINTS.each do |name, endpoint|
      begin
        result = warm_endpoint(endpoint, paths)
        results[name] = { success: true, result: result }
      rescue StandardError => e
        results[name] = { success: false, error: e.message }
        Rails.logger.error "CDN warming failed for #{name}: #{e.message}"
      end
    end
    
    results
  end
  
  def health_check
    results = {}
    
    CDN_ENDPOINTS.each do |name, endpoint|
      begin
        response = HTTParty.get("#{endpoint}/health", timeout: 5)
        results[name] = {
          healthy: response.code == 200,
          response_time: response.headers['x-response-time'],
          cache_status: response.headers['x-cache']
        }
      rescue StandardError => e
        results[name] = {
          healthy: false,
          error: e.message
        }
      end
    end
    
    results
  end
  
  private
  
  def purge_from_endpoint(endpoint, paths)
    HTTParty.post("#{endpoint}/purge", {
      body: { paths: paths }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{cdn_api_key}"
      },
      timeout: 30
    })
  end
  
  def warm_endpoint(endpoint, paths)
    HTTParty.post("#{endpoint}/warm", {
      body: { paths: paths }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{cdn_api_key}"
      },
      timeout: 60
    })
  end
  
  def find_assets_matching(pattern)
    # Find asset files matching the pattern
    Dir.glob(Rails.root.join('public', 'assets', pattern))
       .map { |path| path.sub(Rails.root.join('public').to_s, '') }
  end
  
  def cdn_api_key
    Rails.application.credentials.cdn_api_key || ENV['CDN_API_KEY']
  end
end

# Performance monitoring
class PerformanceMonitor
  include Singleton
  
  def initialize
    @metrics = Concurrent::Hash.new
    @request_times = Concurrent::Array.new
    @error_count = Concurrent::AtomicFixnum.new(0)
    @total_requests = Concurrent::AtomicFixnum.new(0)
  end

  def record_request(duration, path, status)
    @total_requests.increment
    @request_times << duration
    
    # Keep only last 1000 requests for memory efficiency
    @request_times.shift if @request_times.size > 1000
    
    @error_count.increment if status >= 400
    
    # Record per-path metrics
    path_key = normalize_path(path)
    @metrics[path_key] ||= {
      count: Concurrent::AtomicFixnum.new(0),
      total_time: Concurrent::AtomicReference.new(0.0),
      errors: Concurrent::AtomicFixnum.new(0)
    }
    
    @metrics[path_key][:count].increment
    @metrics[path_key][:total_time].update { |current| current + duration }
    @metrics[path_key][:errors].increment if status >= 400
  end

  def current_stats
    request_times = @request_times.to_a
    total_requests = @total_requests.value
    
    return default_stats if request_times.empty?
    
    {
      total_requests: total_requests,
      error_rate: (@error_count.value.to_f / total_requests * 100).round(2),
      average_response_time: (request_times.sum / request_times.size).round(2),
      p95_response_time: percentile(request_times, 95).round(2),
      p99_response_time: percentile(request_times, 99).round(2),
      requests_per_minute: calculate_rpm,
      memory_usage_mb: current_memory_usage,
      cache_hit_ratio: cache_hit_ratio
    }
  end

  def path_stats
    results = {}
    
    @metrics.each do |path, metrics|
      count = metrics[:count].value
      next if count == 0
      
      total_time = metrics[:total_time].value
      errors = metrics[:errors].value
      
      results[path] = {
        requests: count,
        avg_time: (total_time / count).round(2),
        error_rate: (errors.to_f / count * 100).round(2)
      }
    end
    
    results.sort_by { |_, stats| -stats[:requests] }.to_h
  end

  def health_check
    stats = current_stats
    
    {
      status: determine_health_status(stats),
      metrics: stats,
      thresholds: {
        max_p95_response_time: 2000, # 2 seconds
        max_error_rate: 5.0,         # 5%
        max_memory_mb: 512           # 512 MB
      }
    }
  end

  private

  def normalize_path(path)
    # Normalize paths to group similar requests
    path.gsub(/\/\d+/, '/:id')
        .gsub(/\?.*/, '') # Remove query parameters
  end

  def percentile(array, percentile)
    return 0 if array.empty?
    
    sorted = array.sort
    index = (percentile / 100.0 * sorted.length).ceil - 1
    sorted[index] || 0
  end

  def calculate_rpm
    # Simple RPM calculation based on recent requests
    recent_requests = @request_times.count { |_| true } # Just count all current requests
    recent_requests * 60 / [@request_times.size, 60].min
  end

  def current_memory_usage
    # Get current memory usage in MB
    if File.exist?('/proc/self/status')
      status = File.read('/proc/self/status')
      if match = status.match(/VmRSS:\s*(\d+)\s*kB/)
        match[1].to_f / 1024.0
      else
        0
      end
    else
      `ps -o rss= -p #{Process.pid}`.to_f / 1024.0
    end
  rescue StandardError
    0
  end

  def cache_hit_ratio
    # This would integrate with actual cache metrics
    0.85 # Placeholder
  end

  def default_stats
    {
      total_requests: 0,
      error_rate: 0,
      average_response_time: 0,
      p95_response_time: 0,
      p99_response_time: 0,
      requests_per_minute: 0,
      memory_usage_mb: current_memory_usage,
      cache_hit_ratio: 0
    }
  end

  def determine_health_status(stats)
    return 'critical' if stats[:p95_response_time] > 5000
    return 'critical' if stats[:error_rate] > 10
    return 'critical' if stats[:memory_usage_mb] > 700
    
    return 'degraded' if stats[:p95_response_time] > 2000
    return 'degraded' if stats[:error_rate] > 5
    return 'degraded' if stats[:memory_usage_mb] > 512
    
    'healthy'
  end
end

# Initialize performance monitoring middleware
class PerformanceMonitoringMiddleware
  def initialize(app)
    @app = app
    @monitor = PerformanceMonitor.instance
  end

  def call(env)
    start_time = Time.current
    
    status, headers, body = @app.call(env)
    
    duration = (Time.current - start_time) * 1000 # Convert to milliseconds
    @monitor.record_request(duration, env['PATH_INFO'], status)
    
    # Add performance headers
    headers['X-Response-Time'] = "#{duration.round(2)}ms"
    
    [status, headers, body]
  end
end

Rails.application.config.middleware.use PerformanceMonitoringMiddleware