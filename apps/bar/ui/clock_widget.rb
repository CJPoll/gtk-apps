# frozen_string_literal: true

module Bar
  module UI
    class ClockWidget < Gtk::Box
      include GtkKit::Timers

      FORMAT_FULL = '%Y/%m/%d %I:%M %p'
      FORMAT_SHORT = '%I:%M:%S %p'
      UPDATE_INTERVAL_SECONDS = 1

      def initialize
        super(:horizontal, 0)

        setup_ui
        start_timer
      end

      private

      def setup_ui
        @button = Gtk::Button.new(label: formatted_time)
        @button.style_context.add_class('pill')
        @button.style_context.add_class('clock')

        pack_start(@button, expand: false, fill: false, padding: 0)

        setup_tooltip
      end

      def setup_tooltip
        update_tooltip
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) do
          @button.label = formatted_time
          update_tooltip
        end
      end

      def formatted_time
        Time.now.strftime(FORMAT_FULL)
      end

      def update_tooltip
        @button.set_tooltip_text(Time.now.strftime('%Y-%m-%d %H:%M:%S'))
      end
    end
  end
end
