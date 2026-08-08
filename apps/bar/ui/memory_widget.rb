# frozen_string_literal: true

require 'json'

module Bar
  module UI
    class MemoryWidget < Gtk::Box
      include GtkKit::Timers

      SCRIPT_PATH = File.expand_path('~/dev/custom/scripts/waybar-memory-procs')
      UPDATE_INTERVAL_SECONDS = 5

      def initialize
        super(:horizontal, 0)

        setup_ui
        update_display
        start_timer
      end

      private

      def setup_ui
        @button = Gtk::Button.new(label: '')
        @button.add_css_class('pill')
        @button.add_css_class('memory')

        append(@button)
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def update_display
        data = fetch_data
        return unless data

        @button.label = data['text']
        @button.set_tooltip_text(data['tooltip']&.gsub('\\n', "\n"))
      end

      def fetch_data
        Bar::Managers::SharedState.instance.fetch(:memory_data) do
          next nil unless File.executable?(SCRIPT_PATH)

          output = `#{SCRIPT_PATH}`.strip
          JSON.parse(output)
        end
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "MemoryWidget: #{e.message}"
        nil
      end
    end
  end
end
