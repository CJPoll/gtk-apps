# frozen_string_literal: true

module Bar
  module UI
    class BrightnessWidget < Gtk::Box
      include GtkKit::Timers

      UPDATE_INTERVAL_SECONDS = 2
      BRIGHTNESS_STEP = 5

      def initialize
        super(:horizontal, 0)

        @backlight = Adapters::Backlight.detect

        setup_ui
        setup_events
        update_display
        start_timer
      end

      private

      def setup_ui
        @button = Gtk::Button.new(label: '')
        @button.add_css_class('pill')
        @button.add_css_class('brightness')

        append(@button)
      end

      def setup_events
        @button.signal_connect('clicked') { show_slider }

        scroll = Gtk::EventControllerScroll.new(Gtk::EventControllerScrollFlags::VERTICAL)
        scroll.signal_connect('scroll') do |_controller, _dx, dy|
          adjust(Domain::Brightness.scroll_step(dy, BRIGHTNESS_STEP))
          true
        end
        add_controller(scroll)
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def update_display
        percent = current_percent
        return hide_widget unless percent

        self.visible = true
        @button.label = Domain::Brightness.label(percent)
        @button.set_tooltip_text(
          "Brightness: #{percent}%\nClick for slider\nScroll to adjust"
        )
      end

      def hide_widget
        self.visible = false
      end

      def show_slider
        percent = current_percent
        return unless percent

        BrightnessPopover.new(@button, percent: percent, on_change: method(:apply)).popup
      end

      def adjust(delta)
        return if delta.zero?

        percent = current_percent
        return unless percent

        target = Domain::Brightness.clamp(percent + delta)
        apply(target) unless target == percent
      end

      def apply(percent)
        return unless @backlight

        @backlight.raw = Domain::Brightness.to_raw(percent, @backlight.max_raw)
        Bar::Managers::SharedState.instance.invalidate(:brightness_raw)
        update_display
      end

      def current_percent
        return nil unless @backlight

        raw = Bar::Managers::SharedState.instance.fetch(:brightness_raw) { @backlight.raw }
        return nil unless raw

        Domain::Brightness.to_percent(raw, @backlight.max_raw)
      end
    end
  end
end
