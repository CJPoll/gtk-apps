# frozen_string_literal: true

module Bar
  module UI
    class ClockWidget < Gtk::Box
      FORMAT_FULL = '%A, %B %d, %Y  %I:%M %p'
      FORMAT_SHORT = '%I:%M:%S %p'
      UPDATE_INTERVAL_SECONDS = 1

      def initialize
        super(:horizontal, 0)

        setup_ui
        start_timer
      end

      private

      def setup_ui
        @label = Gtk::Label.new(formatted_time)
        @label.style_context.add_class('pill')
        @label.style_context.add_class('clock')

        pack_start(@label, expand: false, fill: false, padding: 0)

        setup_tooltip
      end

      def setup_tooltip
        update_tooltip
      end

      def start_timer
        GLib::Timeout.add_seconds(UPDATE_INTERVAL_SECONDS) do
          @label.text = formatted_time
          update_tooltip
          true # Continue timer
        end
      end

      def formatted_time
        Time.now.strftime(FORMAT_FULL)
      end

      def update_tooltip
        @label.set_tooltip_text(Time.now.strftime('%Y-%m-%d %H:%M:%S'))
      end
    end
  end
end
