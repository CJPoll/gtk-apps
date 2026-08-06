# frozen_string_literal: true

module Bar
  module UI
    class TrayWidget < Gtk::Box
      include WidgetTimers

      ICON_SIZE = 18

      def initialize(sni_host: nil)
        super(:horizontal, 4)

        style_context.add_class('pill')
        style_context.add_class('tray')

        @sni_host = sni_host
        @watcher = nil
        @item_widgets = {}
        @signal_subscriptions = {}
        @connection = nil

        # Start hidden until we have items
        set_no_show_all(true)

        setup_watcher
      end

      def cleanup
        @watcher&.stop
        unsubscribe_all_signals
      end

      private

      def setup_watcher
        @watcher = Bar::Adapters::SniWatcher.new(
          on_items_changed: method(:on_items_changed),
          sni_host: @sni_host
        )
        @watcher.start
      rescue StandardError => e
        warn "TrayWidget: Failed to start SNI watcher: #{e.message}"
        warn e.backtrace.first(3).join("\n")
      end

      def on_items_changed(items)
        # Remove widgets for items that no longer exist
        current_keys = items.map { |i| item_key(i) }
        @item_widgets.keys.each do |key|
          unless current_keys.include?(key)
            unsubscribe_item_signals(key)
            @item_widgets[key].destroy
            @item_widgets.delete(key)
          end
        end

        # Add widgets for new items
        items.each do |item|
          key = item_key(item)
          next if @item_widgets.key?(key)

          widget = create_item_widget(item)
          next unless widget

          @item_widgets[key] = widget
          pack_start(widget, expand: false, fill: false, padding: 0)
          widget.show_all
        end

        # Hide tray when empty, show when items present
        if @item_widgets.empty?
          hide
        else
          show
          children.each(&:show_all)
        end
      end

      def item_key(item)
        "#{item[:bus_name]}#{item[:object_path]}"
      end

      def create_item_widget(item)
        props = @watcher.get_item_properties(item[:bus_name], item[:object_path])
        return nil if props.empty?

        button = Gtk::EventBox.new
        image = create_icon_image(props)
        image.set_size_request(ICON_SIZE, ICON_SIZE)

        button.add(image)
        button.set_size_request(ICON_SIZE + 8, ICON_SIZE + 8)
        button.style_context.add_class('tray-item')

        # Set tooltip - prefer Title, then ToolTipTitle, then Id
        title = props['Title']
        title = props['ToolTipTitle'] if title.nil? || title.empty?
        title = props['Id'] if title.nil? || title.empty?
        title ||= 'Unknown'
        button.set_tooltip_text(title)

        # Handle clicks
        setup_item_events(button, item, props)

        # Subscribe to item changes
        subscribe_to_item_signals(button, image, item)

        button
      end

      def create_icon_image(props)
        status = props['Status'] || 'Active'
        icon_theme_path = props['IconThemePath']

        # When status is NeedsAttention, try attention icons first
        if status == 'NeedsAttention'
          icon = try_load_icon(props['AttentionIconName'], icon_theme_path)
          return icon if icon

          icon = try_load_pixmap_icon(props['AttentionIconPixmap'])
          return icon if icon
        end

        # Try regular IconName
        icon = try_load_icon(props['IconName'], icon_theme_path)
        return icon if icon

        # Try IconPixmap (raw pixel data)
        icon = try_load_pixmap_icon(props['IconPixmap'])
        return icon if icon

        # Fallback icon
        Gtk::Image.new(icon_name: 'application-x-executable', size: :menu)
      end

      def try_load_icon(icon_name, icon_theme_path)
        return nil if icon_name.nil? || icon_name.empty?

        # Check custom IconThemePath first (e.g., Steam uses this)
        if icon_theme_path && !icon_theme_path.empty?
          custom_icon = try_load_custom_icon(icon_theme_path, icon_name)
          return custom_icon if custom_icon
        end

        # Fall back to system icon theme
        icon_theme = Gtk::IconTheme.default
        return nil unless icon_theme.has_icon?(icon_name)

        pixbuf = icon_theme.load_icon(icon_name, ICON_SIZE, :force_size)
        Gtk::Image.new(pixbuf: pixbuf)
      end

      def try_load_pixmap_icon(pixmaps)
        return nil unless pixmaps.is_a?(Array) && !pixmaps.empty?

        pixmap = pixmaps.first
        return nil unless pixmap && pixmap[:data]

        pixbuf = create_pixbuf_from_data(pixmap)
        return nil unless pixbuf

        scaled = pixbuf.scale_simple(ICON_SIZE, ICON_SIZE, GdkPixbuf::InterpType::BILINEAR)
        Gtk::Image.new(pixbuf: scaled)
      end

      def create_pixbuf_from_data(pixmap)
        width = pixmap[:width]
        height = pixmap[:height]
        data = pixmap[:data]

        return nil if data.nil? || data.empty?

        # SNI uses ARGB32, GdkPixbuf uses RGBA
        # Convert ARGB to RGBA
        rgba_data = []
        (0...data.length).step(4) do |i|
          a = data[i]
          r = data[i + 1]
          g = data[i + 2]
          b = data[i + 3]
          rgba_data.push(r, g, b, a)
        end

        GdkPixbuf::Pixbuf.new(
          data: rgba_data.pack('C*'),
          colorspace: GdkPixbuf::Colorspace::RGB,
          has_alpha: true,
          bits_per_sample: 8,
          width: width,
          height: height,
          row_stride: width * 4
        )
      rescue StandardError => e
        warn "TrayWidget: Failed to create pixbuf: #{e.message}"
        nil
      end

      def try_load_custom_icon(theme_path, icon_name)
        # Try common image extensions
        %w[.png .svg .xpm].each do |ext|
          path = File.join(theme_path, "#{icon_name}#{ext}")
          next unless File.exist?(path)

          pixbuf = GdkPixbuf::Pixbuf.new(file: path)
          scaled = pixbuf.scale_simple(ICON_SIZE, ICON_SIZE, GdkPixbuf::InterpType::BILINEAR)
          return Gtk::Image.new(pixbuf: scaled)
        end

        nil
      rescue StandardError => e
        warn "TrayWidget: Failed to load custom icon from #{theme_path}: #{e.message}"
        nil
      end

      def setup_item_events(button, item, props)
        button.add_events(Gdk::EventMask::BUTTON_PRESS_MASK)
        item_is_menu = props['ItemIsMenu'] == true

        button.signal_connect('button-press-event') do |_widget, event|
          x = event.x_root.to_i
          y = event.y_root.to_i

          case event.button
          when 1 # Left click
            if item_is_menu
              @watcher.context_menu_item(item[:bus_name], item[:object_path], x, y)
            else
              @watcher.activate_item(item[:bus_name], item[:object_path], x, y)
            end
          when 2 # Middle click
            @watcher.secondary_activate_item(item[:bus_name], item[:object_path], x, y)
          when 3 # Right click
            @watcher.context_menu_item(item[:bus_name], item[:object_path], x, y)
          end

          true
        end
      end

      def subscribe_to_item_signals(button, image, item)
        key = item_key(item)
        @signal_subscriptions[key] = []

        # Subscribe to NewIcon signal
        sub_id = dbus_connection.signal_subscribe(
          item[:bus_name],
          'org.kde.StatusNotifierItem',
          'NewIcon',
          item[:object_path],
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          on_main_thread { update_item_icon(image, item) }
        end
        @signal_subscriptions[key] << sub_id

        # Subscribe to NewTitle signal
        sub_id = dbus_connection.signal_subscribe(
          item[:bus_name],
          'org.kde.StatusNotifierItem',
          'NewTitle',
          item[:object_path],
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          on_main_thread { update_item_tooltip(button, item) }
        end
        @signal_subscriptions[key] << sub_id

        # Subscribe to NewStatus signal
        sub_id = dbus_connection.signal_subscribe(
          item[:bus_name],
          'org.kde.StatusNotifierItem',
          'NewStatus',
          item[:object_path],
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          on_main_thread { update_item_icon(image, item) }
        end
        @signal_subscriptions[key] << sub_id

        # Subscribe to NewAttentionIcon signal
        sub_id = dbus_connection.signal_subscribe(
          item[:bus_name],
          'org.kde.StatusNotifierItem',
          'NewAttentionIcon',
          item[:object_path],
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          on_main_thread { update_item_icon(image, item) }
        end
        @signal_subscriptions[key] << sub_id

        # Subscribe to NewOverlayIcon signal
        sub_id = dbus_connection.signal_subscribe(
          item[:bus_name],
          'org.kde.StatusNotifierItem',
          'NewOverlayIcon',
          item[:object_path],
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          on_main_thread { update_item_icon(image, item) }
        end
        @signal_subscriptions[key] << sub_id

        # Subscribe to NewToolTip signal
        sub_id = dbus_connection.signal_subscribe(
          item[:bus_name],
          'org.kde.StatusNotifierItem',
          'NewToolTip',
          item[:object_path],
          nil,
          Gio::DBusSignalFlags::NONE
        ) do |_conn, _sender, _path, _iface, _signal, _params|
          on_main_thread { update_item_tooltip(button, item) }
        end
        @signal_subscriptions[key] << sub_id
      end

      def unsubscribe_item_signals(key)
        return unless @signal_subscriptions[key]

        @signal_subscriptions[key].each do |sub_id|
          dbus_connection.signal_unsubscribe(sub_id)
        end
        @signal_subscriptions.delete(key)
      end

      def unsubscribe_all_signals
        @signal_subscriptions.keys.each { |key| unsubscribe_item_signals(key) }
      end

      def dbus_connection
        @connection ||= Gio.bus_get_sync(Gio::BusType::SESSION)
      end

      def update_item_icon(image, item)
        props = @watcher.get_item_properties(item[:bus_name], item[:object_path])
        return if props.empty?

        new_image = create_icon_image(props)
        image.pixbuf = new_image.pixbuf if new_image.pixbuf
      rescue StandardError => e
        warn "TrayWidget: Failed to update icon: #{e.message}"
      end

      def update_item_tooltip(button, item)
        props = @watcher.get_item_properties(item[:bus_name], item[:object_path])
        return if props.empty?

        title = props['Title']
        title = props['ToolTipTitle'] if title.nil? || title.empty?
        title = props['Id'] if title.nil? || title.empty?
        title ||= 'Unknown'
        button.set_tooltip_text(title)
      rescue StandardError => e
        warn "TrayWidget: Failed to update tooltip: #{e.message}"
      end
    end
  end
end
