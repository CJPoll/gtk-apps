# frozen_string_literal: true

module Launcher
  module UI
    class DockIcon < Gtk::Box
      BASE_SIZE = 48
      MAX_SIZE = 72
      # Scale factor to add uniform padding around icons (85% of slot)
      ICON_SCALE = 0.85

      attr_reader :app_entry

      def initialize(app_entry:)
        super(:horizontal, 0)

        @app_entry = app_entry
        @current_size = BASE_SIZE

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
        add_css_class('dock-icon')
        set_valign(:end)
        set_size_request(BASE_SIZE, BASE_SIZE)

        # GTK4 images scale their paintable to pixel-size, replacing the
        # GTK3 pixbuf-rescaling pipeline: set the source once, then resize
        # by changing pixel_size alone.
        @image = Gtk::Image.new
        @image.set_halign(:center)
        @image.set_valign(:center)
        @image.hexpand = true
        set_icon_source(@image)
        @image.pixel_size = (BASE_SIZE * ICON_SCALE).to_i
        append(@image)

        set_tooltip_text(@app_entry.name)
      end

      def set_icon_source(image)
        icon_theme = Gtk::IconTheme.get_for_display(Gdk::Display.default)
        icon_name = @app_entry.icon_name

        if icon_theme.has_icon?(icon_name)
          image.set_from_icon_name(icon_name)
        elsif File.exist?(icon_name)
          image.set_from_file(icon_name)
        elsif (pixmap_path = find_in_pixmaps(icon_name))
          image.set_from_file(pixmap_path)
        elsif (flatpak_path = find_in_flatpak_icons(icon_name))
          image.set_from_file(flatpak_path)
        else
          image.set_from_icon_name('application-x-executable')
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

      def update_icon_size(size)
        set_size_request(size, size)
        @image.pixel_size = (size * ICON_SCALE).to_i
      end

      # Motion tracking lives on the Dock's own controller; the icon only
      # handles launching.
      def setup_events
        click = Gtk::GestureClick.new
        click.button = 1
        click.signal_connect('pressed') { @app_entry.launch }
        add_controller(click)
      end
    end
  end
end
