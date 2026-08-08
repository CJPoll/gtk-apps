# frozen_string_literal: true

module HyprManager
  module Domain
    # ~/hyprland.local.conf, split into the region hypr-manager manages and
    # everything it must never touch. The managed region is the span from the
    # first active `monitor =` or `workspace =` line through the last one —
    # comments and blank lines outside that span (headers, commented-out
    # HOME/WORK blocks, exec-once lines) survive rewrites byte-for-byte.
    # Comments inside the span are considered descriptions of managed lines
    # and are regenerated.
    class LocalConf
      MANAGED = /\A\s*(?:monitor|workspace)\s*=/
      WORKSPACE_BIND = /\A\s*workspace\s*=\s*(\d+)\s*,\s*monitor:(?:desc:)?(.+?)\s*(?:,.*)?\z/

      attr_reader :before, :after, :managed_lines

      def self.parse(content)
        lines = content.split("\n", -1)
        managed_indexes = lines.each_index.select { |i| lines[i].match?(MANAGED) }

        if managed_indexes.empty?
          new(before: lines, managed_lines: [], after: [])
        else
          first, last = managed_indexes.minmax
          new(
            before: lines[0...first],
            managed_lines: lines[first..last],
            after: lines[(last + 1)..]
          )
        end
      end

      def initialize(before:, managed_lines:, after:)
        @before = before
        @managed_lines = managed_lines
        @after = after
      end

      # [[workspace_id, monitor_ref], ...] — refs may be port names or
      # descriptions; the caller resolves them against connected monitors.
      def workspace_binds
        @managed_lines.filter_map do |line|
          match = WORKSPACE_BIND.match(line)
          [match[1].to_i, match[2]] if match
        end
      end

      def render(layout, assignments)
        managed = layout.config_lines + [''] + assignments.config_lines
        sections = []
        sections << @before.join("\n") unless @before.empty?
        sections << managed.join("\n")
        sections << @after.join("\n") unless @after.empty?

        content = sections.join("\n")
        content.end_with?("\n") ? content : "#{content}\n"
      end
    end
  end
end
