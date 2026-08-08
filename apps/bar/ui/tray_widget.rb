# frozen_string_literal: true

module Bar
  module UI
    class TrayWidget < Gtk::Box
      include GtkKit::Timers

      ICON_SIZE = 18

      def initialize(sni_host: nil)
        super(:horizontal, 4)

        add_css_class('pill')
        add_css_class('tray')

        @sni_host = sni_host
        @watcher = nil
        @item_widgets = {}
        @signal_subscriptions = {}
        @connection = nil

        # Start hidden until we have items
        self.visible = false

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
            remove(@item_widgets[key])
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
          append(widget)
        end

        # Hide tray when empty, show when items present
        self.visible = @item_widgets.any?
      end

      def item_key(item)
        "#{item[:bus_name]}#{item[:object_path]}"
      end

      def create_item_widget(item)
        props = @watcher.get_item_properties(item[:bus_name], item[:object_path])
        return nil if props.empty?

        button = Gtk::Box.new(:horizontal, 0)
        image = create_icon_image(props)
        image.set_size_request(ICON_SIZE, ICON_SIZE)

        button.append(image)
        button.set_size_request(ICON_SIZE + 8, ICON_SIZE + 8)
        button.add_css_class('tray-item')

        # Set tooltip - prefer Title, then ToolTipTitle, then Id
        button.set_tooltip_text(item_title(props))

        # Handle clicks
        setup_item_events(button, item, props)

        # Subscribe to item changes
        subscribe_to_item_signals(button, item)

        button
      end

      def item_title(props)
        title = props['Title']
        title = props['ToolTipTitle'] if title.nil? || title.empty?
        title = props['Id'] if title.nil? || title.empty?
        title || 'Unknown'
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
        themed_image('application-x-executable')
      end

      def themed_image(icon_name)
        image = Gtk::Image.new
        image.pixel_size = ICON_SIZE
        image.set_from_icon_name(icon_name)
        image
      end

      def try_load_icon(icon_name, icon_theme_path)
        return nil if icon_name.nil? || icon_name.empty?

        # Check custom IconThemePath first (e.g., Steam uses this)
        if icon_theme_path && !icon_theme_path.empty?
          custom_icon = try_load_custom_icon(icon_theme_path, icon_name)
          return custom_icon if custom_icon
        end

        # Fall back to system icon theme
        icon_theme = Gtk::IconTheme.get_for_display(Gdk::Display.default)
        return nil unless icon_theme.has_icon?(icon_name)

        themed_image(icon_name)
      end

      def try_load_pixmap_icon(pixmaps)
        return nil unless pixmaps.is_a?(Array) && !pixmaps.empty?

        pixmap = pixmaps.first
        return nil unless pixmap && pixmap[:data]

        pixbuf = create_pixbuf_from_data(pixmap)
        return nil unless pixbuf

        scaled = pixbuf.scale_simple(ICON_SIZE, ICON_SIZE, GdkPixbuf::InterpType::BILINEAR)
        image = Gtk::Image.new(pixbuf: scaled)
        image.pixel_size = ICON_SIZE
        image
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

          image = Gtk::Image.new
          image.pixel_size = ICON_SIZE
          image.set_from_file(path)
          return image
        end

        nil
      rescue StandardError => e
        warn "TrayWidget: Failed to load custom icon from #{theme_path}: #{e.message}"
        nil
      end

      def setup_item_events(button, item, props)
        item_is_menu = props['ItemIsMenu'] == true

        gesture = Gtk::GestureClick.new
        gesture.button = 0 # listen for any button
        gesture.signal_connect('pressed') do |g, _n_press, x, y|
          # SNI menu coordinates are best-effort hints; Wayland offers no
          # global coordinates, so pass the click's widget-local position.
          gx = x.to_i
          gy = y.to_i

          case g.current_button
          when 1 # Left click
            if item_is_menu
              @watcher.context_menu_item(item[:bus_name], item[:object_path], gx, gy)
            else
              @watcher.activate_item(item[:bus_name], item[:object_path], gx, gy)
            end
          when 2 # Middle click
            @watcher.secondary_activate_item(item[:bus_name], item[:object_path], gx, gy)
          when 3 # Right click
            @watcher.context_menu_item(item[:bus_name], item[:object_path], gx, gy)
          end
        end
        button.add_controller(gesture)
      end

      ITEM_SIGNALS = {
        'NewIcon' => :icon,
        'NewStatus' => :icon,
        'NewAttentionIcon' => :icon,
        'NewOverlayIcon' => :icon,
        'NewTitle' => :tooltip,
        'NewToolTip' => :tooltip
      }.freeze

      def subscribe_to_item_signals(button, item)
        key = item_key(item)
        @signal_subscriptions[key] = ITEM_SIGNALS.map do |signal_name, kind|
          dbus_connection.signal_subscribe(
            item[:bus_name],
            'org.kde.StatusNotifierItem',
            signal_name,
            item[:object_path],
            nil,
            Gio::DBusSignalFlags::NONE
          ) do |_conn, _sender, _path, _iface, _signal, _params|
            if kind == :icon
              on_main_thread { update_item_icon(button, item) }
            else
              on_main_thread { update_item_tooltip(button, item) }
            end
          end
        end
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

      # GTK4 images have no mutable pixbuf accessor; swap the image widget
      # inside the item's box instead.
      def update_item_icon(button, item)
        props = @watcher.get_item_properties(item[:bus_name], item[:object_path])
        return if props.empty?

        new_image = create_icon_image(props)
        new_image.set_size_request(ICON_SIZE, ICON_SIZE)

        old_image = button.first_child
        button.remove(old_image) if old_image
        button.append(new_image)
      rescue StandardError => e
        warn "TrayWidget: Failed to update icon: #{e.message}"
      end

      def update_item_tooltip(button, item)
        props = @watcher.get_item_properties(item[:bus_name], item[:object_path])
        return if props.empty?

        button.set_tooltip_text(item_title(props))
      rescue StandardError => e
        warn "TrayWidget: Failed to update tooltip: #{e.message}"
      end
    end
  end
end
