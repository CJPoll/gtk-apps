# frozen_string_literal: true

require 'json'

module Bar
  module UI
    class BatteryWidget < Gtk::Box
      include GtkKit::Timers

      SCRIPT_PATH = File.expand_path('~/dev/custom/scripts/waybar-battery')
      UPDATE_INTERVAL_SECONDS = 10
      PULSE_INTERVAL_MS = 600

      def initialize
        super(:horizontal, 0)

        @pulse_state = false
        @is_critical = false

        setup_ui
        update_display
        start_timer
        start_pulse_timer
      end

      private

      def setup_ui
        @button = Gtk::Button.new(label: '')
        @button.add_css_class('pill')
        @button.add_css_class('battery')

        append(@button)
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def start_pulse_timer
        every_ms(PULSE_INTERVAL_MS) do
          @pulse_state = !@pulse_state
          update_pulse_state
        end
      end

      def update_pulse_state
        return unless @is_critical

        if @pulse_state
          @button.add_css_class('pulse-bright')
        else
          @button.remove_css_class('pulse-bright')
        end
      end

      def update_display
        data = fetch_data
        return hide_widget unless data
        return hide_widget if data['class'] == 'hidden'

        self.visible = true
        @button.label = data['text']
        @button.set_tooltip_text(data['tooltip']&.gsub('\\n', "\n"))

        # Update CSS class for state styling
        update_style_class(data['class'])
      end

      def hide_widget
        self.visible = false
      end

      def update_style_class(css_class)
        %w[charging plugged warning critical pulse-bright].each do |c|
          @button.remove_css_class(c)
        end
        @button.add_css_class(css_class) if css_class && !css_class.empty?

        # Track critical state for pulse animation
        @is_critical = (css_class == 'critical')
      end

      def fetch_data
        Bar::Managers::SharedState.instance.fetch(:battery_data) do
          next nil unless File.executable?(SCRIPT_PATH)

          output = `#{SCRIPT_PATH}`.strip
          JSON.parse(output)
        end
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "BatteryWidget: #{e.message}"
        nil
      end
    end
  end
end
