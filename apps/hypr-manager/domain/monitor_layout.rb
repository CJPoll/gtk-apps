# frozen_string_literal: true

module HyprManager
  module Domain
    # The left-to-right arrangement of connected monitors. Order is the
    # source of truth; x positions are always recomputed from it, so a
    # reorder, resolution change, or rotation keeps monitors edge-to-edge
    # in a single row (y = 0).
    class MonitorLayout
      attr_reader :monitors

      def initialize(monitors)
        @monitors = monitors.sort_by(&:x)
        reposition!
      end

      def find(description)
        @monitors.find { |monitor| monitor.description == description }
      end

      # Moves a monitor to the slot currently occupied by another.
      def reorder(description, before_description)
        moving = find(description)
        return if moving.nil? || description == before_description

        @monitors.delete(moving)
        target_index = @monitors.index { |m| m.description == before_description }
        target_index ? @monitors.insert(target_index, moving) : @monitors.push(moving)
        reposition!
      end

      def set_mode(description, mode)
        find(description)&.apply_mode(mode)
        reposition!
      end

      def set_transform(description, transform)
        monitor = find(description)
        return unless monitor

        monitor.transform = transform
        reposition!
      end

      def config_lines
        lines = ['# Managed by hypr-manager']
        @monitors.each { |monitor| lines.concat(monitor.config_lines) }
        lines << '# Catch-all for any other display that gets plugged in'
        lines << 'monitor = ,preferred, auto, 1'
        lines
      end

      private

      def reposition!
        x = 0
        @monitors.each do |monitor|
          monitor.x = x
          monitor.y = 0
          x += monitor.effective_width
        end
      end
    end
  end
end
