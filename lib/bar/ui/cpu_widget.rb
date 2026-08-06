# frozen_string_literal: true

module Bar
  module UI
    class CpuWidget < Gtk::Box
      include WidgetTimers

      UPDATE_INTERVAL_SECONDS = 2

      def initialize
        super(:horizontal, 0)

        @prev_idle = 0
        @prev_total = 0

        setup_ui
        update_display
        start_timer
      end

      private

      def setup_ui
        @button = Gtk::Button.new(label: '')
        @button.style_context.add_class('pill')
        @button.style_context.add_class('cpu')

        pack_start(@button, expand: false, fill: false, padding: 0)
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def update_display
        usage = calculate_cpu_usage
        @button.label = "#{usage}% CPU"
        @button.set_tooltip_text("CPU Usage: #{usage}%")
      end

      def calculate_cpu_usage
        # Read /proc/stat - first line is aggregate CPU stats
        line = File.readlines('/proc/stat').first
        values = line.split[1..].map(&:to_i)

        # values: user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice
        idle = values[3] + values[4]  # idle + iowait
        total = values.sum

        # Calculate difference from last reading
        idle_delta = idle - @prev_idle
        total_delta = total - @prev_total

        @prev_idle = idle
        @prev_total = total

        return 0 if total_delta == 0

        usage = ((total_delta - idle_delta) * 100.0 / total_delta).round
        usage.clamp(0, 100)
      rescue Errno::ENOENT
        0
      end
    end
  end
end
