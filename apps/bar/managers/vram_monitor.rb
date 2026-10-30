# frozen_string_literal: true

module Bar
  module Managers
    # Owns VRAM sampling for every bar on every monitor: one nvidia-smi call
    # per MAX_AGE_SECONDS however many VramWidgets ask.
    #
    # #current blocks for the length of an nvidia-smi call, so callers invoke
    # it from a worker thread, never the GTK main loop. It holds its own mutex
    # rather than SharedState's, whose lock the memory widget takes on the
    # main loop and must not wait behind a ~100 ms GPU query.
    #
    # Returns a Domain::Vram::Snapshot, or nil while VRAM cannot be read.
    # An outage is warned about once (and again only after a recovery), so a
    # machine without nvidia-smi does not log a line every few seconds.
    class VramMonitor
      MAX_AGE_SECONDS = 4

      class << self
        def instance
          @instance ||= new(source: Adapters::NvidiaSmi.new)
        end
      end

      def initialize(source:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                     warn: ->(message) { Kernel.warn(message) })
        @source = source
        @clock = clock
        @warn = warn
        @mutex = Mutex.new
        @sampled_at = nil
        @snapshot = nil
        @warned = false
      end

      def current
        @mutex.synchronize do
          return @snapshot if @sampled_at && @clock.call - @sampled_at < MAX_AGE_SECONDS

          @snapshot = sample
          @sampled_at = @clock.call
          @snapshot
        end
      end

      private

      def sample
        snapshot = @source.sample
        @warned = false
        snapshot
      rescue Adapters::NvidiaSmi::Unavailable => e
        report(e.message)
      rescue StandardError => e
        report("#{e.class}: #{e.message}")
      end

      def report(message)
        @warn.call("VramWidget: #{message}") unless @warned
        @warned = true
        nil
      end
    end
  end
end
