# frozen_string_literal: true

module Bar
  module UI
    class AudioSinkWidget < Gtk::EventBox
      UPDATE_INTERVAL_SECONDS = 2

      def initialize
        super

        @button = Gtk::Button.new(label: '')
        @button.style_context.add_class('pill')
        @button.style_context.add_class('audio-sink')

        add(@button)

        setup_events
        update_display
        start_timer
      end

      private

      def setup_events
        @button.signal_connect('button-press-event') do |_widget, event|
          show_sink_picker(event) if event.button == 1
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
        current_sink = get_current_sink
        return unless current_sink

        icon = get_sink_icon(current_sink[:name])
        short = short_name(current_sink[:name])

        @button.label = "#{icon} #{short}"
        @button.set_tooltip_text("Audio: #{current_sink[:name]}")
      end

      def show_sink_picker(event)
        menu = Gtk::Menu.new

        sinks = get_sinks
        current_id = get_current_sink&.dig(:id)

        sinks.each do |sink|
          item = Gtk::MenuItem.new(label: "#{get_sink_icon(sink[:name])} #{short_name(sink[:name])}")

          if sink[:id] == current_id
            item.sensitive = false
          end

          item.signal_connect('activate') do
            set_default_sink(sink[:id])
            update_display
          end

          menu.append(item)
        end

        menu.show_all
        menu.popup_at_pointer(event)
      end

      def get_current_sink
        Bar::Managers::SharedState.instance.fetch(:current_audio_sink) do
          parse_current_sink
        end
      end

      def parse_current_sink
        output = `wpctl status 2>/dev/null`
        in_audio = false
        in_sinks = false

        output.each_line do |line|
          in_audio = true if line.match?(/^Audio/)
          next unless in_audio

          in_sinks = true if line.include?('Sinks:')
          break if in_sinks && line.include?('Sources:')

          next unless in_sinks && line.include?('*') && line.include?('[vol:')

          # Parse: " │  *   92. WH-1000XM5  [vol: 0.43]"
          match = line.match(/\*\s*(\d+)\.\s+(.+?)\s+\[vol:/)
          next unless match

          return { id: match[1], name: match[2].strip }
        end

        nil
      rescue Errno::ENOENT
        nil
      end

      def get_sinks
        sinks = []
        output = `wpctl status 2>/dev/null`
        in_audio = false
        in_sinks = false

        output.each_line do |line|
          in_audio = true if line.match?(/^Audio/)
          next unless in_audio

          in_sinks = true if line.include?('Sinks:')
          break if in_sinks && line.include?('Sources:')

          next unless in_sinks && line.include?('[vol:')

          # Parse: " │      34. Device Name [vol: 0.40]" or " │  *   92. Device [vol: 0.43]"
          match = line.match(/(\d+)\.\s+(.+?)\s+\[vol:/)
          next unless match

          sinks << { id: match[1], name: match[2].strip }
        end

        sinks
      rescue Errno::ENOENT
        []
      end

      def set_default_sink(sink_id)
        system('wpctl', 'set-default', sink_id.to_s)
        Bar::Managers::SharedState.instance.invalidate(:current_audio_sink)
      end

      def get_sink_icon(sink_name)
        case sink_name
        when /WH-1000XM5|bluez|Bluetooth|headset|Headphones/i
          '󰋋'
        when /HDMI|hdmi/i
          '󰡁'
        when /Yeti|USB|usb/i
          '󰍬'
        else
          '󰓃'
        end
      end

      def short_name(name)
        name = name.to_s.strip

        if name.include?('WH-1000XM5')
          'XM5'
        elsif name.include?('Family 17h') || name.include?('HD Audio Controller Analog')
          'Speakers'
        elsif name.include?('HDMI') || name.include?('Digital Stereo')
          'HDMI'
        elsif name.include?('Yeti')
          'Yeti'
        elsif name.include?('Gemini') || name.include?('BeatGrip')
          'BeatGrip'
        else
          name[0, 12]
        end
      end
    end
  end
end
