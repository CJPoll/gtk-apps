# frozen_string_literal: true

module Bar
  module Adapters
    # StatusNotifierWatcher host - registers the D-Bus service that apps connect to
    class SniHost
      WATCHER_BUS_NAME = 'org.kde.StatusNotifierWatcher'
      WATCHER_OBJECT_PATH = '/StatusNotifierWatcher'
      WATCHER_INTERFACE = 'org.kde.StatusNotifierWatcher'

      INTROSPECTION_XML = <<~XML
        <!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
          "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
        <node>
          <interface name="org.kde.StatusNotifierWatcher">
            <method name="RegisterStatusNotifierItem">
              <arg direction="in" type="s" name="service"/>
            </method>
            <method name="RegisterStatusNotifierHost">
              <arg direction="in" type="s" name="service"/>
            </method>
            <signal name="StatusNotifierItemRegistered">
              <arg type="s" name="service"/>
            </signal>
            <signal name="StatusNotifierItemUnregistered">
              <arg type="s" name="service"/>
            </signal>
            <signal name="StatusNotifierHostRegistered"/>
            <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
            <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
            <property name="ProtocolVersion" type="i" access="read"/>
          </interface>
          <interface name="org.freedesktop.DBus.Properties">
            <method name="Get">
              <arg direction="in" type="s" name="interface"/>
              <arg direction="in" type="s" name="property"/>
              <arg direction="out" type="v" name="value"/>
            </method>
            <method name="GetAll">
              <arg direction="in" type="s" name="interface"/>
              <arg direction="out" type="a{sv}" name="properties"/>
            </method>
          </interface>
        </node>
      XML

      PROPERTIES_INTERFACE = 'org.freedesktop.DBus.Properties'

      attr_reader :registered_items

      def initialize(on_item_registered: nil, on_item_unregistered: nil)
        @registered_items = []
        @registered_hosts = []
        @on_item_registered = on_item_registered
        @on_item_unregistered = on_item_unregistered
        @connection = nil
        @bus_name_id = 0
        @registration_ids = []
      end

      def start
        @connection = Gio.bus_get_sync(Gio::BusType::SESSION)

        # Parse introspection data with both interfaces
        node_info = Gio::DBusNodeInfo.new(INTROSPECTION_XML)

        # Register the watcher interface
        watcher_interface = node_info.lookup_interface(WATCHER_INTERFACE)
        reg_id = @connection.register_object(
          WATCHER_OBJECT_PATH,
          watcher_interface
        ) do |conn, sender, path, iface, method_name, params, invocation|
          handle_method_call(conn, sender, path, iface, method_name, params, invocation)
        end
        @registration_ids << reg_id

        # Register the standard Properties interface
        properties_interface = node_info.lookup_interface(PROPERTIES_INTERFACE)
        reg_id = @connection.register_object(
          WATCHER_OBJECT_PATH,
          properties_interface
        ) do |conn, sender, path, iface, method_name, params, invocation|
          handle_method_call(conn, sender, path, iface, method_name, params, invocation)
        end
        @registration_ids << reg_id

        # Own the bus name
        @bus_name_id = Gio.bus_own_name(
          Gio::BusType::SESSION,
          WATCHER_BUS_NAME,
          Gio::BusNameOwnerFlags::NONE
        )

        # Watch for clients disconnecting
        watch_for_disconnects

        self
      end

      def register_self_as_host
        # Register ourselves as a StatusNotifierHost
        host_name = "org.freedesktop.StatusNotifierHost-#{Process.pid}"
        register_host(host_name)
        emit_host_registered
      end

      def stop
        @registration_ids.each do |reg_id|
          @connection&.unregister_object(reg_id) if reg_id > 0
        end
        @registration_ids.clear

        if @bus_name_id > 0
          Gio.bus_unown_name(@bus_name_id)
          @bus_name_id = 0
        end
      end

      private

      def handle_method_call(_conn, sender, _path, interface, method_name, parameters, invocation)
        # parameters may be Array or GLib::Variant depending on Ruby-GNOME version
        params = parameters.is_a?(Array) ? parameters : extract_params(parameters)

        case interface
        when PROPERTIES_INTERFACE
          handle_properties_call(method_name, params, invocation)
        when WATCHER_INTERFACE
          handle_watcher_call(sender, method_name, params, invocation)
        else
          warn "SniHost: Unknown interface: #{interface}"
          invocation.return_value(nil)
        end
      rescue StandardError => e
        warn "SniHost: Error handling #{interface}.#{method_name}: #{e.message}"
        warn e.backtrace.first(3).join("\n")
        # Try to return something to avoid hanging
        begin
          invocation.return_value(nil)
        rescue StandardError
          # Ignore if we can't return
        end
      end

      def handle_properties_call(method_name, params, invocation)
        case method_name
        when 'Get'
          property_name = params[1].to_s
          value = get_property_variant_str(property_name)
          response = "(<#{value}>,)"
          invocation.return_value(GLib::Variant.parse(response))
        when 'GetAll'
          host_registered = @registered_hosts.any?
          items_str = @registered_items.map { |i| "'#{i}'" }.join(', ')
          dict = "{'RegisteredStatusNotifierItems': <@as [#{items_str}]>, " \
                 "'IsStatusNotifierHostRegistered': <#{host_registered}>, 'ProtocolVersion': <0>}"
          invocation.return_value(GLib::Variant.parse("(#{dict},)"))
        else
          warn "SniHost: Unknown Properties method: #{method_name}"
          invocation.return_value(nil)
        end
      end

      def handle_watcher_call(sender, method_name, params, invocation)
        case method_name
        when 'RegisterStatusNotifierItem'
          service = params[0].to_s
          register_item(sender, service)
          invocation.return_value(nil)
        when 'RegisterStatusNotifierHost'
          service = params[0].to_s
          register_host(service)
          invocation.return_value(nil)
        else
          warn "SniHost: Unknown Watcher method: #{method_name}"
          invocation.return_value(nil)
        end
      end

      def extract_params(variant)
        count = variant.n_children
        (0...count).map { |i| variant.get_child_value(i).value }
      end

      def get_property_variant_str(property_name)
        case property_name
        when 'RegisteredStatusNotifierItems'
          items_str = @registered_items.map { |i| "'#{i}'" }.join(', ')
          "@as [#{items_str}]"
        when 'IsStatusNotifierHostRegistered'
          'true'
        when 'ProtocolVersion'
          '0'
        else
          "''"
        end
      end

      def register_item(sender, service)
        # Service can be a bus name or object path
        # If it's just an object path, use the sender's bus name
        item_id = if service.start_with?('/')
                    "#{sender}#{service}"
                  elsif service.start_with?(':')
                    "#{service}/StatusNotifierItem"
                  else
                    service
                  end

        return if @registered_items.include?(item_id)

        @registered_items << item_id
        emit_item_registered(item_id)
        @on_item_registered&.call(item_id)
      end

      def register_host(service)
        return if @registered_hosts.include?(service)

        @registered_hosts << service
        emit_host_registered
      end

      def unregister_item(item_id)
        return unless @registered_items.include?(item_id)

        @registered_items.delete(item_id)
        emit_item_unregistered(item_id)
        @on_item_unregistered&.call(item_id)
      end

      def emit_item_registered(item_id)
        @connection.emit_signal(
          nil, # destination (nil = broadcast)
          WATCHER_OBJECT_PATH,
          WATCHER_INTERFACE,
          'StatusNotifierItemRegistered',
          GLib::Variant.parse("('#{item_id}',)")
        )
      end

      def emit_item_unregistered(item_id)
        @connection.emit_signal(
          nil,
          WATCHER_OBJECT_PATH,
          WATCHER_INTERFACE,
          'StatusNotifierItemUnregistered',
          GLib::Variant.parse("('#{item_id}',)")
        )
      end

      def emit_host_registered
        @connection.emit_signal(
          nil,
          WATCHER_OBJECT_PATH,
          WATCHER_INTERFACE,
          'StatusNotifierHostRegistered',
          nil
        )
      end

      def watch_for_disconnects
        @connection.signal_subscribe(
          'org.freedesktop.DBus',
          'org.freedesktop.DBus',
          'NameOwnerChanged',
          '/org/freedesktop/DBus',
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, params|
          begin
            # params may be Array or GLib::Variant depending on Ruby-GNOME version
            name, _old_owner, new_owner = if params.is_a?(Array)
                                            params
                                          else
                                            [
                                              params.get_child_value(0).get_string,
                                              params.get_child_value(1).get_string,
                                              params.get_child_value(2).get_string
                                            ]
                                          end

            # If new_owner is empty, the name was released (client disconnected)
            next unless new_owner.to_s.empty?

            # Check if any registered items belong to this bus name
            items_to_remove = @registered_items.select { |item| item.start_with?(name.to_s) }
            items_to_remove.each do |item_id|
              # Remove directly, don't use Idle.add to avoid timing issues
              @registered_items.delete(item_id)
              # Emit signal in a thread to avoid blocking
              Thread.new do
                emit_item_unregistered(item_id)
              rescue StandardError => e
                warn "SniHost: Error emitting unregister signal: #{e.message}"
              end
            end
          rescue StandardError => e
            warn "SniHost: Error in disconnect handler: #{e.message}"
          end
        end
      end
    end
  end
end
