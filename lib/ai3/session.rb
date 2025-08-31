# frozen_string_literal: true

module Ai3
  # Session management with LRU eviction and context merging
  class Session
    attr_reader :id, :created_at, :last_accessed_at, :context_history

    def initialize(id)
      @id = id
      @created_at = Time.current
      @last_accessed_at = Time.current
      @context_history = []
      @mutex = Mutex.new
    end

    def add_context(prompt, context = {})
      @mutex.synchronize do
        entry = {
          prompt: prompt,
          context: context,
          timestamp: Time.current.iso8601,
          token_count: estimate_tokens(prompt)
        }
        
        @context_history << entry
        touch
        
        # Maintain reasonable context window (max 4000 tokens)
        prune_context_if_needed
      end
    end

    def merged_context
      @mutex.synchronize do
        return "" if @context_history.empty?

        # Merge all context entries with timestamps
        merged = @context_history.map do |entry|
          context_str = entry[:context].any? ? " [Context: #{entry[:context]}]" : ""
          "[#{entry[:timestamp]}] #{entry[:prompt]}#{context_str}"
        end.join("\n\n")

        merged
      end
    end

    def context_length
      @context_history.sum { |entry| entry[:token_count] }
    end

    def touch
      @last_accessed_at = Time.current
    end

    def expired?(ttl_seconds = 3600)
      Time.current - @last_accessed_at > ttl_seconds
    end

    private

    def estimate_tokens(text)
      # Simple token estimation (roughly 4 characters per token)
      (text.length / 4.0).ceil
    end

    def prune_context_if_needed
      max_tokens = 4000
      
      while context_length > max_tokens && @context_history.length > 1
        # Remove oldest entries while preserving recent context
        @context_history.shift
      end
    end
  end

  # LRU session eviction manager
  class SessionEviction
    def initialize(max_size:)
      @max_size = max_size
    end

    def make_room_if_needed(sessions_map)
      return if sessions_map.size < @max_size

      # Find least recently used sessions
      sessions_with_access_time = sessions_map.map do |id, session|
        [id, session.last_accessed_at]
      end

      # Sort by last accessed time (oldest first)
      sorted_sessions = sessions_with_access_time.sort_by { |_, time| time }
      
      # Remove oldest sessions until we're under the limit
      to_remove = sorted_sessions.size - @max_size + 1
      
      sorted_sessions.first(to_remove).each do |session_id, _|
        sessions_map.delete(session_id)
        Rails.logger.info "Evicted session #{session_id} due to LRU policy"
      end
    end
  end
end