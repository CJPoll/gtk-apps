# frozen_string_literal: true

module Bar
  module UI
    class VolumeWidget < Gtk::EventBox
      UPDATE_INTERVAL_SECONDS = 1
      VOLUME_STEP = 5

      def initialize
        super

        @label = Gtk::Label.new('')
        @label.style_context.add_class('pill')
        @label.style_context.add_class('volume')

        add(@label)

        setup_events
        update_display
        start_timer
      end

      private

      def setup_events
        add_events(Gdk::EventMask::SCROLL_MASK)

        signal_connect('button-press-event') do |_widget, event|
          toggle_mute if event.button == 1
          true
        end

        signal_connect('scroll-event') do |_widget, event|
          case event.direction
          when Gdk::ScrollDirection::UP
            adjust_volume(VOLUME_STEP)
          when Gdk::ScrollDirection::DOWN
            adjust_volume(-VOLUME_STEP)
          end
          true
        end
      end

      def start_timer
        GLib::Timeout.add_seconds(UPDATE_INTERVAL_SECONDS) do
          update_display
          true
        end
      end

      def update_display
        volume = get_volume
        muted = muted?

        if muted
          @label.text = '󰝟 Muted'
          @label.style_context.add_class('muted')
        else
          @label.text = "󰕾 #{volume}%"
          @label.style_context.remove_class('muted')
        end

        @label.set_tooltip_text("Volume: #{volume}%#{muted ? ' (Muted)' : ''}\nClick to toggle mute\nScroll to adjust")
      end

      def get_volume
        output = `pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null`.strip
        match = output.match(/(\d+)%/)
        match ? match[1].to_i : 0
      rescue Errno::ENOENT
        0
      end

      def muted?
        output = `pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null`.strip
        output.include?('yes')
      rescue Errno::ENOENT
        false
      end

      def toggle_mute
        system('pactl', 'set-sink-mute', '@DEFAULT_SINK@', 'toggle')
        update_display
      end

      def adjust_volume(delta)
        sign = delta.positive? ? '+' : ''
        system('pactl', 'set-sink-volume', '@DEFAULT_SINK@', "#{sign}#{delta}%")
        update_display
      end
    end
  end
end
