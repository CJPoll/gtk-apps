# frozen_string_literal: true

require 'json'

module Bar
  module UI
    class BatteryWidget < Gtk::Box
      SCRIPT_PATH = File.expand_path('~/dev/custom/scripts/waybar-battery')
      UPDATE_INTERVAL_SECONDS = 10

      def initialize
        super(:horizontal, 0)

        setup_ui
        update_display
        start_timer
      end

      private

      def setup_ui
        @label = Gtk::Label.new('')
        @label.style_context.add_class('pill')
        @label.style_context.add_class('battery')

        pack_start(@label, expand: false, fill: false, padding: 0)
      end

      def start_timer
        GLib::Timeout.add_seconds(UPDATE_INTERVAL_SECONDS) do
          update_display
          true # Continue timer
        end
      end

      def update_display
        data = fetch_data
        return hide_widget unless data
        return hide_widget if data['class'] == 'hidden'

        show
        @label.text = data['text']
        @label.set_tooltip_text(data['tooltip']&.gsub('\\n', "\n"))

        # Update CSS class for state styling
        update_style_class(data['class'])
      end

      def hide_widget
        hide
      end

      def update_style_class(css_class)
        style = @label.style_context
        %w[charging plugged warning critical].each do |c|
          style.remove_class(c)
        end
        style.add_class(css_class) if css_class && !css_class.empty?
      end

      def fetch_data
        return nil unless File.executable?(SCRIPT_PATH)

        output = `#{SCRIPT_PATH}`.strip
        JSON.parse(output)
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "BatteryWidget: #{e.message}"
        nil
      end
    end
  end
end
