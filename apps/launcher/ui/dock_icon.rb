# frozen_string_literal: true

module Launcher
  module UI
    class DockIcon < Gtk::EventBox
      BASE_SIZE = 48
      MAX_SIZE = 72
      # Scale factor to add uniform padding around icons (85% of slot)
      ICON_SCALE = 0.85

      attr_reader :app_entry
      attr_accessor :dock

      def initialize(app_entry:)
        super()

        @app_entry = app_entry
        @dock = nil
        @current_size = BASE_SIZE
        @base_pixbuf = nil

        setup_ui
        setup_events
      end

      def update_scale(scale_factor)
        new_size = (BASE_SIZE + (MAX_SIZE - BASE_SIZE) * scale_factor).to_i
        return if new_size == @current_size

        @current_size = new_size
        update_icon_size(new_size)
      end

      def reset_scale
        return if @current_size == BASE_SIZE

        @current_size = BASE_SIZE
        update_icon_size(BASE_SIZE)
      end

      private

      def setup_ui
        style_context.add_class('dock-icon')
        set_valign(:end)
        set_size_request(BASE_SIZE, BASE_SIZE)

        load_base_pixbuf
        @image = Gtk::Image.new(pixbuf: scale_pixbuf(BASE_SIZE))
        @image.set_halign(:center)
        @image.set_valign(:center)
        add(@image)

        set_tooltip_text(@app_entry.name)
      end

      def load_base_pixbuf
        icon_theme = Gtk::IconTheme.default
        icon_name = @app_entry.icon_name

        @base_pixbuf = if icon_theme.has_icon?(icon_name)
                         icon_theme.load_icon(icon_name, MAX_SIZE, :force_size)
                       elsif File.exist?(icon_name)
                         load_pixbuf_from_file(icon_name)
                       elsif (pixmap_path = find_in_pixmaps(icon_name))
                         load_pixbuf_from_file(pixmap_path)
                       elsif (flatpak_path = find_in_flatpak_icons(icon_name))
                         load_pixbuf_from_file(flatpak_path)
                       else
                         icon_theme.load_icon('application-x-executable', MAX_SIZE, :force_size)
                       end
      end

      def find_in_pixmaps(icon_name)
        %w[svg png xpm].each do |ext|
          path = "/usr/share/pixmaps/#{icon_name}.#{ext}"
          return path if File.exist?(path)
        end
        nil
      end

      def find_in_flatpak_icons(icon_name)
        # Check flatpak icon exports (prefer larger sizes)
        %w[128x128 64x64 48x48 32x32].each do |size|
          %w[svg png].each do |ext|
            path = "/var/lib/flatpak/exports/share/icons/hicolor/#{size}/apps/#{icon_name}.#{ext}"
            return path if File.exist?(path)
          end
        end
        nil
      end

      def load_pixbuf_from_file(path)
        GdkPixbuf::Pixbuf.new(file: path, width: MAX_SIZE, height: MAX_SIZE)
      end

      def scale_pixbuf(size)
        # Scale icon to 85% of slot size for uniform padding
        icon_size = (size * ICON_SCALE).to_i
        @base_pixbuf.scale_simple(icon_size, icon_size, GdkPixbuf::InterpType::BILINEAR)
      end

      def update_icon_size(size)
        set_size_request(size, size)
        @image.pixbuf = scale_pixbuf(size)
      end

      def setup_events
        add_events(Gdk::EventMask::POINTER_MOTION_MASK |
                   Gdk::EventMask::ENTER_NOTIFY_MASK |
                   Gdk::EventMask::LEAVE_NOTIFY_MASK)

        signal_connect('button-press-event') do |_widget, event|
          @app_entry.launch if event.button == 1
          true
        end

        signal_connect('motion-notify-event') do |widget, _event|
          notify_dock_of_motion(widget)
          false
        end

        signal_connect('enter-notify-event') do |widget, _event|
          notify_dock_of_motion(widget)
          false
        end

        signal_connect('leave-notify-event') do |_widget, event|
          # Only notify if leaving to outside dock
          @dock&.on_icon_leave(event.detail) if event.detail != Gdk::NotifyType::INFERIOR
          false
        end
      end

      def notify_dock_of_motion(widget)
        return unless @dock

        # Get pointer position in dock coordinates
        _window, x, _y, _mask = @dock.window.get_device_position(
          Gdk::Display.default.default_seat.pointer
        )
        @dock.on_pointer_motion(x)
      end
    end
  end
end
