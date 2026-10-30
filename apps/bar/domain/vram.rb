# frozen_string_literal: true

module Bar
  module Domain
    # Pure parsing and presentation of NVIDIA VRAM usage.
    #
    # The source is `nvidia-smi -q -x`: one call carries the device name, the
    # framebuffer total/used, and every graphics AND compute process with its
    # used_memory (`--query-compute-apps` lists compute processes only).
    #
    # Memory figures are MiB integers, or nil where the driver reports N/A.
    # nil means "unknown" and is never treated as 0: an N/A process still
    # appears in the tooltip, and its memory is still inside the device-wide
    # used figure, which nvidia-smi measures independently of the process list.
    module Vram
      Snapshot = Data.define(:gpu_name, :total_mib, :used_mib, :processes)

      # process_name is what nvidia-smi reports. comm and args are read from
      # /proc by the adapter when the process is still alive, and stay nil
      # when it has exited between the two reads.
      GpuProcess = Data.define(:pid, :process_name, :used_mib, :comm, :args) do
        def initialize(pid:, process_name:, used_mib:, comm: nil, args: nil)
          super
        end
      end

      # used_mib sums the processes that reported a figure (nil if none did);
      # unknown counts the ones that reported N/A.
      AppUsage = Data.define(:name, :used_mib, :unknown)

      TOP_APPS = 10

      # Same grouping as the RAM widget's waybar-memory-procs, plus Firefox's
      # content processes, which run as "Isolated Web Co".
      APP_GROUPS = [
        [/\Asteam/, 'Steam'],
        [/discord/, 'Discord'],
        [/claude/, 'Claude'],
        [/firefox|\Aisolated web/, 'Firefox'],
        [/chrom/, 'Chrome'],
        [/electron/, 'Electron'],
        [/slack/, 'Slack'],
        [/spotify/, 'Spotify'],
        [/\Acode\z/, 'VS Code'],
        [/\Abrowser|webkit/, 'Browser']
      ].freeze

      INTERPRETER = /\A(ruby|python\d*(\.\d+)?|node|perl)\z/
      SCRIPT = /\.(rb|py|js|mjs|pl)\z/
      GENERIC_SCRIPT = /\A(main|index|__main__|app)\z/

      ENTITIES = { '&amp;' => '&', '&lt;' => '<', '&gt;' => '>', '&quot;' => '"', '&apos;' => "'" }.freeze

      module_function

      # The first GPU in `nvidia-smi -q -x` output, or nil if there is none
      # (driver not loaded, garbage, empty output).
      def parse(xml)
        gpu = xml.to_s[%r{<gpu\b[^>]*>(.*?)</gpu>}m, 1]
        return nil unless gpu

        fb = gpu[%r{<fb_memory_usage>(.*?)</fb_memory_usage>}m, 1].to_s

        Snapshot.new(
          gpu_name: tag(gpu, 'product_name'),
          total_mib: parse_mib(tag(fb, 'total')),
          used_mib: parse_mib(tag(fb, 'used')),
          processes: parse_processes(gpu)
        )
      end

      def parse_processes(gpu)
        block = gpu[%r{<processes>(.*?)</processes>}m, 1].to_s
        block.scan(%r{<process_info>(.*?)</process_info>}m).map do |(info)|
          GpuProcess.new(
            pid: tag(info, 'pid').to_i,
            process_name: tag(info, 'process_name').to_s,
            used_mib: parse_mib(tag(info, 'used_memory'))
          )
        end
      end

      # "469 MiB" -> 469. "N/A", "[N/A]", blank -> nil (unknown, never 0).
      def parse_mib(text)
        match = text.to_s.strip.match(/\A(\d+)\s*MiB\z/)
        match && match[1].to_i
      end

      def tag(xml, name)
        value = xml[%r{<#{name}>(.*?)</#{name}>}m, 1]
        value && value.strip.gsub(/&(amp|lt|gt|quot|apos);/, ENTITIES)
      end

      # Display name for one process: the live comm when we have it, else the
      # basename of nvidia-smi's path; an interpreter is named by its script so
      # two Ruby apps do not merge into one "ruby" row.
      def app_name(process_name:, comm: nil, args: nil)
        base = comm.to_s.strip
        base = File.basename(process_name.to_s) if base.empty?

        group = APP_GROUPS.find { |pattern, _| base.downcase.match?(pattern) }
        return group[1] if group

        return base unless base.match?(INTERPRETER)

        script = Array(args).drop(1).find { |arg| arg.match?(SCRIPT) }
        script ? "#{script_name(script)} (#{base})" : base
      end

      def script_name(path)
        name = File.basename(path, '.*')
        name.match?(GENERIC_SCRIPT) ? File.basename(File.dirname(path)) : name
      end

      # Processes grouped by app, largest known usage first; apps whose every
      # process reported N/A sort after the rest instead of vanishing.
      def top_apps(processes, limit: TOP_APPS)
        processes
          .group_by { |p| app_name(process_name: p.process_name, comm: p.comm, args: p.args) }
          .map { |name, procs| app_usage(name, procs) }
          .sort_by { |app| [app.used_mib ? 0 : 1, -(app.used_mib || 0), app.name] }
          .first(limit)
      end

      def app_usage(name, procs)
        known = procs.map(&:used_mib).compact
        AppUsage.new(name: name, used_mib: known.empty? ? nil : known.sum, unknown: procs.size - known.size)
      end

      def percent(snapshot)
        return nil unless snapshot.used_mib && snapshot.total_mib&.positive?

        (snapshot.used_mib * 100.0 / snapshot.total_mib).round.clamp(0, 100)
      end

      def label(snapshot)
        pct = percent(snapshot)
        pct ? "#{pct}% VRAM" : 'n/a VRAM'
      end

      # MiB in the RAM widget's units: one decimal of G from 1 GiB up, whole M below.
      def format_size(mib)
        return 'n/a' if mib.nil?

        mib >= 1024 ? format('%.1fG', mib / 1024.0) : "#{mib}M"
      end

      def tooltip(snapshot, limit: TOP_APPS)
        pct = percent(snapshot)
        lines = [
          "VRAM: #{pct ? "#{pct}%" : 'n/a'} (#{format_size(snapshot.used_mib)} / #{format_size(snapshot.total_mib)})",
          "GPU: #{snapshot.gpu_name}",
          '',
          '=== VRAM Hogs ==='
        ]
        apps = top_apps(snapshot.processes, limit: limit)
        lines.concat(apps.empty? ? ['  (no GPU processes)'] : apps.map { |app| hog_line(app) })
        note = unknown_note(snapshot)
        lines.push('', note) if note
        lines.join("\n")
      end

      def hog_line(app)
        size = format('%7s', format_size(app.used_mib))
        return "#{size}  #{app.name}" if app.unknown.zero? || app.used_mib.nil?

        "#{size}+ #{app.name} (#{app.unknown} n/a)"
      end

      def unknown_note(snapshot)
        count = snapshot.processes.count { |p| p.used_mib.nil? }
        return nil if count.zero?

        subject = count == 1 ? '1 process reports' : "#{count} processes report"
        "#{subject} n/a; their memory is still in the #{format_size(snapshot.used_mib)} used"
      end
    end
  end
end
