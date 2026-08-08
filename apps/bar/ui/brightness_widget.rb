# frozen_string_literal: true

require 'json'

module Bar
  module UI
    class BrightnessWidget < Gtk::Box
      include GtkKit::Timers

      SCRIPT_PATH = File.expand_path('~/dev/custom/scripts/waybar-brightness')
      UPDATE_INTERVAL_SECONDS = 2

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
        @button.style_context.add_class('brightness')

        pack_start(@button, expand: false, fill: false, padding: 0)
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def update_display
        data = fetch_data
        return hide_widget unless data
        return hide_widget if data['class'] == 'hidden'

        show
        @button.label = data['text']
        @button.set_tooltip_text(data['tooltip']&.gsub('\\n', "\n"))
      end

      def hide_widget
        hide
      end

      def fetch_data
        Bar::Managers::SharedState.instance.fetch(:brightness_data) do
          next nil unless File.executable?(SCRIPT_PATH)

          output = `#{SCRIPT_PATH}`.strip
          JSON.parse(output)
        end
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "BrightnessWidget: #{e.message}"
        nil
      end
    end
  end
end
