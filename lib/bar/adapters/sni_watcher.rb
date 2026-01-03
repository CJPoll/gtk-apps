# frozen_string_literal: true

require 'json'

module Bar
  module Adapters
    # StatusNotifierItem Watcher adapter
    # Uses gdbus CLI tool due to Ruby-GNOME binding limitations with a{sv} types
    class SniWatcher
      WATCHER_BUS_NAME = 'org.kde.StatusNotifierWatcher'
      WATCHER_OBJECT_PATH = '/StatusNotifierWatcher'
      WATCHER_INTERFACE = 'org.kde.StatusNotifierWatcher'
      SNI_INTERFACE = 'org.kde.StatusNotifierItem'

      attr_reader :items

      def initialize(on_items_changed: nil, sni_host: nil)
        @items = []
        @on_items_changed = on_items_changed
        @sni_host = sni_host
        @connection = nil
        @signal_subscriptions = []
      end

      def start
        @connection = Gio.bus_get_sync(Gio::BusType::SESSION)

        # Get initial registered items
        refresh_items

        # Subscribe to item registration/unregistration signals
        subscribe_to_signals

        self
      end

      def stop
        @signal_subscriptions.each do |sub_id|
          @connection.signal_unsubscribe(sub_id)
        end
        @signal_subscriptions.clear
      end

      def refresh_items
        # If we have a direct reference to the host, use it (avoids D-Bus deadlock)
        if @sni_host
          item_names = @sni_host.registered_items
          @items = item_names.map { |item| parse_item_address(item) }
        else
          # Fall back to D-Bus query (for external watcher scenario)
          @items = fetch_items_via_dbus
        end

        @on_items_changed&.call(@items)
      rescue StandardError => e
        warn "SniWatcher: Failed to get registered items: #{e.message}"
        @items = []
      end

      def fetch_items_via_dbus
        output = `timeout 2 gdbus call --session \
          --dest #{WATCHER_BUS_NAME} \
          --object-path #{WATCHER_OBJECT_PATH} \
          --method org.freedesktop.DBus.Properties.Get \
          #{WATCHER_INTERFACE} RegisteredStatusNotifierItems 2>&1`

        if output =~ /<(?:@as )?\[([^\]]*)\]>/
          items_str = $1
          item_names = items_str.scan(/'([^']+)'/).flatten
          item_names.map { |item| parse_item_address(item) }
        else
          []
        end
      end

      def get_item_properties(bus_name, object_path)
        output = `gdbus call --session \
          --dest #{bus_name} \
          --object-path #{object_path} \
          --method org.freedesktop.DBus.Properties.GetAll \
          #{SNI_INTERFACE} 2>/dev/null`

        parse_properties_output(output)
      rescue StandardError => e
        warn "SniWatcher: Failed to get item properties: #{e.message}"
        {}
      end

      def activate_item(bus_name, object_path, x, y)
        `gdbus call --session \
          --dest #{bus_name} \
          --object-path #{object_path} \
          --method #{SNI_INTERFACE}.Activate \
          #{x} #{y} 2>/dev/null`
      rescue StandardError => e
        warn "SniWatcher: Failed to activate item: #{e.message}"
      end

      def secondary_activate_item(bus_name, object_path, x, y)
        `gdbus call --session \
          --dest #{bus_name} \
          --object-path #{object_path} \
          --method #{SNI_INTERFACE}.SecondaryActivate \
          #{x} #{y} 2>/dev/null`
      rescue StandardError => e
        warn "SniWatcher: Failed to secondary activate item: #{e.message}"
      end

      def context_menu_item(bus_name, object_path, x, y)
        `gdbus call --session \
          --dest #{bus_name} \
          --object-path #{object_path} \
          --method #{SNI_INTERFACE}.ContextMenu \
          #{x} #{y} 2>/dev/null`
      rescue StandardError => e
        warn "SniWatcher: Failed to show context menu: #{e.message}"
      end

      private

      def subscribe_to_signals
        # StatusNotifierItemRegistered
        sub_id = @connection.signal_subscribe(
          WATCHER_BUS_NAME,
          WATCHER_INTERFACE,
          'StatusNotifierItemRegistered',
          WATCHER_OBJECT_PATH,
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          GLib::Idle.add do
            refresh_items
            false
          end
        end
        @signal_subscriptions << sub_id

        # StatusNotifierItemUnregistered
        sub_id = @connection.signal_subscribe(
          WATCHER_BUS_NAME,
          WATCHER_INTERFACE,
          'StatusNotifierItemUnregistered',
          WATCHER_OBJECT_PATH,
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          GLib::Idle.add do
            refresh_items
            false
          end
        end
        @signal_subscriptions << sub_id
      end

      def parse_item_address(address)
        # Format is either "bus_name/object_path" or just "bus_name" (with default path)
        if address.include?('/')
          parts = address.split('/', 2)
          { bus_name: parts[0], object_path: "/#{parts[1]}" }
        else
          { bus_name: address, object_path: '/StatusNotifierItem' }
        end
      end

      def parse_properties_output(output)
        props = {}

        # Extract IconName
        if output =~ /'IconName': <'([^']*)'>/
          props['IconName'] = $1
        end

        # Extract Title
        if output =~ /'Title': <'([^']*)'>/
          props['Title'] = $1
        end

        # Extract Id
        if output =~ /'Id': <'([^']*)'>/
          props['Id'] = $1
        end

        # Extract Category
        if output =~ /'Category': <'([^']*)'>/
          props['Category'] = $1
        end

        # Extract Status
        if output =~ /'Status': <'([^']*)'>/
          props['Status'] = $1
        end

        # Extract IconThemePath (custom icon directory)
        if output =~ /'IconThemePath': <'([^']*)'>/
          props['IconThemePath'] = $1
        end

        # Extract ToolTip title (often has the app name)
        if output =~ /'ToolTip': <\([^,]*, [^,]*, '([^']*)',/
          props['ToolTipTitle'] = $1
        end

        # Extract IconPixmap - format: 'IconPixmap': <[(width, height, [byte 0xNN, 0xNN, ...])]>
        props['IconPixmap'] = parse_pixmap(output, 'IconPixmap')

        # Extract AttentionIconName
        if output =~ /'AttentionIconName': <'([^']*)'>/
          props['AttentionIconName'] = $1
        end

        # Extract AttentionIconPixmap
        props['AttentionIconPixmap'] = parse_pixmap(output, 'AttentionIconPixmap')

        # Extract OverlayIconName
        if output =~ /'OverlayIconName': <'([^']*)'>/
          props['OverlayIconName'] = $1
        end

        # Extract OverlayIconPixmap
        props['OverlayIconPixmap'] = parse_pixmap(output, 'OverlayIconPixmap')

        # Extract ItemIsMenu
        if output =~ /'ItemIsMenu': <(true|false)>/
          props['ItemIsMenu'] = $1 == 'true'
        end

        # Extract Menu (object path to dbusmenu)
        if output =~ /'Menu': <objectpath '([^']+)'>/
          props['Menu'] = $1
        end

        props
      end

      def parse_pixmap(output, property_name)
        return nil unless output =~ /'#{property_name}': <\[\((\d+), (\d+), \[byte ([^\]]+)\]\)\]>/

        width = $1.to_i
        height = $2.to_i
        bytes_str = $3

        # Parse byte values: "0x00, 0x00, 0xff" etc
        bytes = bytes_str.scan(/0x([0-9a-f]{2})/i).flatten.map { |b| b.to_i(16) }

        return nil unless bytes.length == width * height * 4

        [{ width: width, height: height, data: bytes }]
      end
    end
  end
end
