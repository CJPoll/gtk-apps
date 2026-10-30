# frozen_string_literal: true

require 'open3'

module Bar
  module Adapters
    # Reads VRAM usage from the proprietary NVIDIA driver. There are no sysfs
    # counters for it on this driver, so nvidia-smi is the only source.
    #
    # One read-only `nvidia-smi -q -x` (about 100 ms) per sample: it carries the
    # device total/used and every graphics and compute process. Each process is
    # then enriched with its /proc comm and cmdline when it is still alive, so
    # Domain::Vram can name it. Callers run this off the GTK main loop.
    #
    # Returns a Domain::Vram::Snapshot; raises Unavailable when nvidia-smi is
    # missing, fails, hangs past TIMEOUT_SECONDS, or reports no GPU.
    class NvidiaSmi
      class Unavailable < StandardError; end

      Result = Data.define(:stdout, :stderr, :success)

      TIMEOUT_SECONDS = 5
      # coreutils timeout bounds a wedged driver so a stuck call cannot hold
      # the sampling thread forever.
      COMMAND = ['timeout', TIMEOUT_SECONDS.to_s, 'nvidia-smi', '-q', '-x'].freeze

      def self.run(command)
        stdout, stderr, status = Open3.capture3(*command)
        Result.new(stdout: stdout, stderr: stderr, success: status.success?)
      end

      def initialize(runner: self.class.method(:run), proc_root: '/proc')
        @runner = runner
        @proc_root = proc_root
      end

      def sample
        result = @runner.call(COMMAND)
        raise Unavailable, failure_message(result) unless result.success

        snapshot = Domain::Vram.parse(result.stdout)
        raise Unavailable, 'nvidia-smi reported no GPU' unless snapshot

        snapshot.with(processes: snapshot.processes.map { |process| enrich(process) })
      rescue Errno::ENOENT
        raise Unavailable, 'nvidia-smi not found'
      end

      private

      def failure_message(result)
        line = [result.stderr, result.stdout].map { |text| text.to_s.lines.map(&:strip).find { |l| !l.empty? } }
                                             .compact.first
        "nvidia-smi failed: #{line || 'no output'}"
      end

      def enrich(process)
        dir = File.join(@proc_root, process.pid.to_s)
        process.with(comm: read(File.join(dir, 'comm'))&.strip,
                     args: read(File.join(dir, 'cmdline'))&.split("\0"))
      end

      # A process can exit between nvidia-smi listing it and this read.
      def read(path)
        File.read(path)
      rescue SystemCallError, IOError
        nil
      end
    end
  end
end
