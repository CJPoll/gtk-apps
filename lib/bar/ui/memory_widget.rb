# frozen_string_literal: true

require 'json'

module Bar
  module UI
    class MemoryWidget < Gtk::Box
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
        @button.style_context.add_class('pill')
        @button.style_context.add_class('memory')

        pack_start(@button, expand: false, fill: false, padding: 0)
      end

      def start_timer
        GLib::Timeout.add_seconds(UPDATE_INTERVAL_SECONDS) do
          update_display
          true # Continue timer
        end
      end

      def update_display
        data = fetch_data
        return unless data

        @button.label = data['text']
        @button.set_tooltip_text(data['tooltip']&.gsub('\\n', "\n"))
      end

      def fetch_data
        return nil unless File.executable?(SCRIPT_PATH)

        output = `#{SCRIPT_PATH}`.strip
        JSON.parse(output)
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "MemoryWidget: #{e.message}"
        nil
      end
    end
  end
end
