# frozen_string_literal: true

require 'json'

module Bar
  module UI
    class BatteryWidget < Gtk::Box
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
        @button.style_context.add_class('pill')
        @button.style_context.add_class('battery')

        pack_start(@button, expand: false, fill: false, padding: 0)
      end

      def start_timer
        GLib::Timeout.add_seconds(UPDATE_INTERVAL_SECONDS) do
          update_display
          true # Continue timer
        end
      end

      def start_pulse_timer
        GLib::Timeout.add(PULSE_INTERVAL_MS) do
          @pulse_state = !@pulse_state
          update_pulse_state
          true # Continue timer
        end
      end

      def update_pulse_state
        return unless @is_critical

        style = @button.style_context
        if @pulse_state
          style.add_class('pulse-bright')
        else
          style.remove_class('pulse-bright')
        end
      end

      def update_display
        data = fetch_data
        return hide_widget unless data
        return hide_widget if data['class'] == 'hidden'

        show
        @button.label = data['text']
        @button.set_tooltip_text(data['tooltip']&.gsub('\\n', "\n"))

        # Update CSS class for state styling
        update_style_class(data['class'])
      end

      def hide_widget
        hide
      end

      def update_style_class(css_class)
        style = @button.style_context
        %w[charging plugged warning critical pulse-bright].each do |c|
          style.remove_class(c)
        end
        style.add_class(css_class) if css_class && !css_class.empty?

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
