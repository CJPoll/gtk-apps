# frozen_string_literal: true

module Bar
  module UI
    class NetworkWidget < Gtk::EventBox
      include WidgetTimers

      UPDATE_INTERVAL_SECONDS = 5

      def initialize
        super

        @button = Gtk::Button.new(label: '')
        @button.style_context.add_class('pill')
        @button.style_context.add_class('network')
        @wifi_interface = find_wifi_interface

        add(@button)

        setup_events
        update_display
        start_timer
      end

      private

      def setup_events
        @button.signal_connect('button-press-event') do |_widget, event|
          show_network_menu(event) if event.button == 1
          true
        end
      end

      def show_network_menu(event)
        menu = Gtk::Menu.new

        # Current connection info
        status = get_network_status
        if status[:connected]
          current_item = Gtk::MenuItem.new(label: "✓ #{status[:name]}")
          current_item.sensitive = false
          menu.append(current_item)

          # Separator
          menu.append(Gtk::SeparatorMenuItem.new)
        end

        # Scan for networks
        scan_item = Gtk::MenuItem.new(label: '󰍉 Scan for networks...')
        scan_item.signal_connect('activate') { trigger_scan }
        menu.append(scan_item)

        menu.append(Gtk::SeparatorMenuItem.new)

        # Available networks from scan results
        networks = get_scan_results
        if networks.any?
          networks.first(15).each do |network|
            next if network[:ssid].empty?
            next if status[:connected] && network[:ssid] == status[:name]

            icon = wifi_icon(network[:signal])
            item = Gtk::MenuItem.new(label: "#{icon} #{network[:ssid]} (#{network[:signal]}%)")
            item.signal_connect('activate') { connect_to_network(network[:ssid]) }
            menu.append(item)
          end

          menu.append(Gtk::SeparatorMenuItem.new)
        end

        # Disconnect option if connected
        if status[:connected] && status[:type] == :wifi
          disconnect_item = Gtk::MenuItem.new(label: '󰖪 Disconnect')
          disconnect_item.signal_connect('activate') { disconnect_wifi }
          menu.append(disconnect_item)
        end

        menu.show_all
        menu.popup_at_pointer(event)
      end

      def trigger_scan
        return unless @wifi_interface

        Thread.new do
          `wpa_cli -i #{@wifi_interface} scan 2>/dev/null`
          sleep 2 # Wait for scan to complete

          on_main_thread { update_display }
        end
      end

      def get_scan_results
        return [] unless @wifi_interface

        output = `wpa_cli -i #{@wifi_interface} scan_results 2>/dev/null`
        parse_scan_results(output)
      rescue Errno::ENOENT
        []
      end

      def parse_scan_results(output)
        networks = []

        output.each_line.with_index do |line, index|
          next if index == 0 # Skip header line

          parts = line.strip.split("\t")
          next if parts.length < 5

          signal_dbm = parts[2].to_i
          ssid = parts[4] || ''

          networks << {
            bssid: parts[0],
            frequency: parts[1].to_i,
            signal: dbm_to_percent(signal_dbm),
            flags: parts[3],
            ssid: ssid
          }
        end

        # Remove duplicates (same SSID), keep strongest signal
        networks
          .reject { |n| n[:ssid].empty? }
          .group_by { |n| n[:ssid] }
          .map { |_ssid, nets| nets.max_by { |n| n[:signal] } }
          .sort_by { |n| -(n[:signal] || 0) }
      end

      def connect_to_network(ssid)
        return unless @wifi_interface

        # Show connecting state immediately
        @button.label = "󰤫 Connecting..."
        @button.set_tooltip_text("Connecting to #{ssid}...")

        Thread.new do
          # Check if network is already configured
          list_output = `wpa_cli -i #{@wifi_interface} list_networks 2>/dev/null`
          network_id = nil

          list_output.each_line.with_index do |line, index|
            next if index == 0
            parts = line.strip.split("\t")
            if parts[1] == ssid
              network_id = parts[0]
              break
            end
          end

          if network_id
            # Network exists, select it
            `wpa_cli -i #{@wifi_interface} select_network #{network_id} 2>/dev/null`

            # Poll for connection status
            10.times do
              sleep 1
              status = `wpa_cli -i #{@wifi_interface} status 2>/dev/null`
              if status.include?('wpa_state=COMPLETED')
                break
              end
            end
          else
            # Network not configured - would need password
            warn "Network '#{ssid}' not configured. Add it to wpa_supplicant.conf first."
          end

          on_main_thread { update_display }
        end
      end

      def disconnect_wifi
        return unless @wifi_interface

        pid = spawn('wpa_cli', '-i', @wifi_interface, 'disconnect',
                    pgroup: true, [:out, :err] => '/dev/null')
        Process.detach(pid)

        after_ms(1000) { update_display }
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_display }
      end

      def update_display
        status = get_network_status

        if status[:connected]
          icon = status[:type] == :wifi ? wifi_icon(status[:signal]) : '󰈀'
          @button.label = icon
          @button.style_context.remove_class('disconnected')

          tooltip = "#{status[:type] == :wifi ? 'WiFi' : 'Ethernet'}: #{status[:name]}"
          tooltip += "\nFrequency: #{status[:frequency]}" if status[:frequency]
          tooltip += "\nSignal: #{status[:signal]}%" if status[:signal]
          tooltip += "\nIP: #{status[:ip]}" if status[:ip]
          @button.set_tooltip_text(tooltip)
        else
          @button.label = '󰌙 Disconnected'
          @button.style_context.add_class('disconnected')
          @button.set_tooltip_text('No network connection')
        end
      end

      def get_network_status
        # Check for WiFi first
        wifi_status = get_wifi_status
        return wifi_status if wifi_status[:connected]

        # Check for Ethernet
        ethernet_status = get_ethernet_status
        return ethernet_status if ethernet_status[:connected]

        { connected: false }
      end

      def get_wifi_status
        interface = find_wifi_interface
        return { connected: false } unless interface

        output = `iw dev #{interface} link 2>/dev/null`
        return { connected: false } if output.include?('Not connected')

        ssid = output[/SSID: (.+)/, 1]
        signal_dbm = output[/signal: (-?\d+)/, 1]&.to_i
        freq_mhz = output[/freq: ([\d.]+)/, 1]&.to_f

        return { connected: false } unless ssid

        {
          connected: true,
          type: :wifi,
          name: ssid,
          signal: dbm_to_percent(signal_dbm),
          frequency: format_frequency(freq_mhz),
          ip: get_interface_ip(interface)
        }
      rescue Errno::ENOENT
        { connected: false }
      end

      def get_ethernet_status
        interface = find_ethernet_interface
        return { connected: false } unless interface

        # Check if interface is up and has carrier
        state = File.read("/sys/class/net/#{interface}/operstate").strip
        return { connected: false } unless state == 'up'

        {
          connected: true,
          type: :ethernet,
          name: interface,
          ip: get_interface_ip(interface)
        }
      rescue Errno::ENOENT
        { connected: false }
      end

      def find_wifi_interface
        Dir.glob('/sys/class/net/wl*').first&.then { |p| File.basename(p) }
      end

      def find_ethernet_interface
        Dir.glob('/sys/class/net/en*').first&.then { |p| File.basename(p) }
      end

      def get_interface_ip(interface)
        output = `ip -4 addr show #{interface} 2>/dev/null`
        output[/inet (\d+\.\d+\.\d+\.\d+)/, 1]
      rescue Errno::ENOENT
        nil
      end

      def dbm_to_percent(dbm)
        return nil unless dbm

        # Rough conversion: -30 dBm = 100%, -90 dBm = 0%
        percent = ((dbm + 90) * 100 / 60.0).round
        percent.clamp(0, 100)
      end

      def format_frequency(freq_mhz)
        return nil unless freq_mhz && freq_mhz > 0

        case freq_mhz
        when 2400..2500
          '2.4 GHz'
        when 5000..5900
          '5 GHz'
        when 5925..7125
          '6 GHz'
        else
          "#{(freq_mhz / 1000.0).round(1)} GHz"
        end
      end

      def wifi_icon(signal)
        case signal
        when 75..100 then '󰤨'
        when 50..74 then '󰤥'
        when 25..49 then '󰤢'
        when 1..24 then '󰤟'
        else '󰤯'
        end
      end

    end
  end
end
