# frozen_string_literal: true

module Bar
  module Managers
    # Shared state manager for system-wide data
    # Prevents redundant shell commands when multiple monitors exist
    class SharedState
      DEFAULT_TTL = 2 # seconds

      class << self
        def instance
          @instance ||= new
        end

        def reset!
          @instance = nil
        end
      end

      def initialize
        @cache = {}
        @timestamps = {}
        @mutex = Mutex.new
      end

      # Cache a value by key with TTL, computing only if expired or missing
      def fetch(key, ttl: DEFAULT_TTL, &block)
        @mutex.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          if @cache.key?(key) && (now - @timestamps[key]) < ttl
            return @cache[key]
          end

          @cache[key] = block.call
          @timestamps[key] = now
          @cache[key]
        end
      end

      # Invalidate a specific key (for refresh)
      def invalidate(key)
        @mutex.synchronize do
          @cache.delete(key)
          @timestamps.delete(key)
        end
      end

      # Invalidate all cached data
      def invalidate_all
        @mutex.synchronize do
          @cache.clear
          @timestamps.clear
        end
      end
    end
  end
end
