# frozen_string_literal: true

module Bar
  module UI
    class AudioSinkWidget < Gtk::Box
      include GtkKit::Timers

      UPDATE_INTERVAL_SECONDS = 2

      def initialize
        super(:horizontal, 0)

        @button = Gtk::Button.new(label: '')
        @button.add_css_class('pill')
        @button.add_css_class('audio-sink')

        append(@button)

        setup_events
        update_display
        start_timer
      end

      private

      def setup_events
        @button.signal_connect('clicked') { show_sink_picker }
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def update_display
        current_sink = get_current_sink
        return unless current_sink

        icon = get_sink_icon(current_sink[:name])
        short = short_name(current_sink[:name])

        @button.label = "#{icon} #{short}"
        @button.set_tooltip_text("Audio: #{current_sink[:name]}")
      end

      def show_sink_picker
        menu = MenuPopover.new(@button)

        sinks = get_sinks
        current_id = get_current_sink&.dig(:id)

        sinks.each do |sink|
          label = "#{get_sink_icon(sink[:name])} #{short_name(sink[:name])}"
          menu.add_item(label, sensitive: sink[:id] != current_id) do
            if bluetooth_sink?(sink[:name])
              switch_to_a2dp
            else
              set_default_sink(sink[:id])
            end
            update_display
          end
        end

        menu.popup
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

        # set-default only routes *new* streams; anything already playing stays
        # on the old sink until it is moved explicitly.
        sink_name = sink_name_for(sink_id)
        move_sink_inputs(sink_name) if sink_name

        Bar::Managers::SharedState.instance.invalidate(:current_audio_sink)
      end

      # wpctl node ids and pactl sink indices are separate id spaces, so the
      # node id cannot be handed to pactl directly. node.name is shared by both.
      def sink_name_for(sink_id)
        output = `wpctl inspect #{sink_id} 2>/dev/null`
        match = output.match(/node\.name\s*=\s*"([^"]+)"/)
        match && match[1]
      rescue Errno::ENOENT
        nil
      end

      def bluetooth_sink?(sink_name)
        sink_name.to_s.match?(/WH-1000XM5|bluez|Bluetooth/i)
      end

      def switch_to_a2dp
        card_name = find_bluez_card
        return unless card_name

        system('pactl', 'set-card-profile', card_name, 'a2dp-sink')
        sink_name = find_bluez_sink
        return unless sink_name

        system('pactl', 'set-default-sink', sink_name)
        move_sink_inputs(sink_name)
        Bar::Managers::SharedState.instance.invalidate(:current_audio_sink)
      end

      def find_bluez_card
        output = `pactl list cards short 2>/dev/null`
        output.each_line do |line|
          name = line.split[1]
          return name if name&.start_with?('bluez_card.')
        end
        nil
      end

      def find_bluez_sink
        output = `pactl list sinks short 2>/dev/null`
        output.each_line do |line|
          name = line.split[1]
          return name if name&.start_with?('bluez_output.')
        end
        nil
      end

      def move_sink_inputs(sink_name)
        output = `pactl list sink-inputs short 2>/dev/null`
        output.each_line do |line|
          input_id = line.split[0]
          next unless input_id

          # Streams created with node.dont-reconnect (Steam, some games) refuse
          # to move for their entire lifetime. Skip past them quietly rather
          # than logging a failure on every sink switch.
          system('pactl', 'move-sink-input', input_id, sink_name, err: File::NULL)
        end
      rescue Errno::ENOENT
        nil
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
