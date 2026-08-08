# frozen_string_literal: true

module Bar
  module UI
    class VolumeWidget < Gtk::Box
      include GtkKit::Timers

      UPDATE_INTERVAL_SECONDS = 1
      VOLUME_STEP = 5

      def initialize
        super(:horizontal, 0)

        @button = Gtk::Button.new(label: '')
        @button.add_css_class('pill')
        @button.add_css_class('volume')

        append(@button)

        setup_events
        update_display
        start_timer
      end

      private

      def setup_events
        @button.signal_connect('clicked') do
          toggle_mute
        end

        scroll = Gtk::EventControllerScroll.new(Gtk::EventControllerScrollFlags::VERTICAL)
        scroll.signal_connect('scroll') do |_controller, _dx, dy|
          adjust_volume(dy.negative? ? VOLUME_STEP : -VOLUME_STEP)
          true
        end
        add_controller(scroll)
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def update_display
        volume = get_volume
        muted = muted?

        if muted
          @button.label = '󰝟 Muted'
          @button.add_css_class('muted')
        else
          @button.label = "󰕾 #{volume}%"
          @button.remove_css_class('muted')
        end

        @button.set_tooltip_text("Volume: #{volume}%#{muted ? ' (Muted)' : ''}\nClick to toggle mute\nScroll to adjust")
      end

      def get_volume
        Bar::Managers::SharedState.instance.fetch(:volume_level) do
          output = `pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null`.strip
          match = output.match(/(\d+)%/)
          match ? match[1].to_i : 0
        end
      rescue Errno::ENOENT
        0
      end

      def muted?
        Bar::Managers::SharedState.instance.fetch(:volume_muted) do
          output = `pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null`.strip
          output.include?('yes')
        end
      rescue Errno::ENOENT
        false
      end

      def toggle_mute
        system('pactl', 'set-sink-mute', '@DEFAULT_SINK@', 'toggle')
        invalidate_cache
        update_display
      end

      def adjust_volume(delta)
        sign = delta.positive? ? '+' : ''
        system('pactl', 'set-sink-volume', '@DEFAULT_SINK@', "#{sign}#{delta}%")
        invalidate_cache
        update_display
      end

      def invalidate_cache
        state = Bar::Managers::SharedState.instance
        state.invalidate(:volume_level)
        state.invalidate(:volume_muted)
      end
    end
  end
end
