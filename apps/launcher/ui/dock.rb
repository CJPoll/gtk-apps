# frozen_string_literal: true

module Launcher
  module UI
    class Dock < Gtk::EventBox
      # Desktop file names (without .desktop extension)
      DOCK_APPS = %w[
        Alacritty
        org.mozilla.firefox
        discord
        spotify
        slack
        steam
        pyrope
        beryl
      ].freeze

      # Magnification effect radius in pixels
      MAGNIFICATION_RADIUS = 100
      # Base icon size + padding for position calculation
      ICON_SLOT_WIDTH = DockIcon::BASE_SIZE + 8 + 8 # icon + padding on each side

      # Height of the visual dock box (base size + padding + extra bottom)
      DOCK_BOX_HEIGHT = DockIcon::BASE_SIZE + 16 + 8
      # Height of EventBox to accommodate max icon size extending above
      DOCK_HEIGHT = DockIcon::MAX_SIZE + 24

      def initialize
        super()

        @icons = []
        @icon_centers = [] # Cached center positions

        # Fixed height container to prevent jitter
        set_size_request(-1, DOCK_HEIGHT)
        set_valign(:end)

        # Use overlay so icons can extend above the background
        @overlay = Gtk::Overlay.new
        @overlay.set_halign(:center)
        @overlay.set_valign(:end)

        # Background container (full height, transparent)
        @bg_container = Gtk::Box.new(:vertical, 0)
        @bg_container.set_valign(:end)

        # Visual background (styled, fixed height at bottom)
        @background = Gtk::Box.new(:horizontal, 0)
        @background.style_context.add_class('dock-background')
        @background.set_size_request(-1, DOCK_BOX_HEIGHT)
        @bg_container.pack_end(@background, expand: false, fill: true, padding: 0)

        @overlay.add(@bg_container)

        # Icon container (overlaid, can extend above background)
        @icon_box = Gtk::Box.new(:horizontal, 8)
        @icon_box.style_context.add_class('dock-icons')
        @icon_box.set_halign(:center)
        @icon_box.set_valign(:end)
        @overlay.add_overlay(@icon_box)

        # Set fixed width after icons are added (prevents re-centering jitter)
        signal_connect_after('map') do
          # Lock the icon box width to its initial size
          alloc = @icon_box.allocation
          @icon_box.set_size_request(alloc.width, -1)
          @background.set_size_request(alloc.width, DOCK_BOX_HEIGHT)
          @bg_container.set_size_request(alloc.width, DOCK_HEIGHT)
          false
        end

        add(@overlay)

        setup_icons
        setup_events
      end

      def on_pointer_motion(cursor_x)
        update_magnification(cursor_x)
      end

      def on_icon_leave(detail)
        # Check if we're still inside the dock
        return if detail == Gdk::NotifyType::ANCESTOR

        _window, x, y, _mask = window.get_device_position(
          Gdk::Display.default.default_seat.pointer
        )

        # Only reset if pointer is outside dock bounds
        # Allow y to extend below the dock (into the margin area at bottom of screen)
        alloc = allocation
        in_horizontal_bounds = x >= 0 && x <= alloc.width
        in_vertical_bounds = y >= 0 # No lower bound - allow below dock

        unless in_horizontal_bounds && in_vertical_bounds
          reset_magnification
        end
      end

      private

      def setup_icons
        DOCK_APPS.each do |app_name|
          app_entry = Domain::AppEntry.from_desktop_file(app_name)
          next unless app_entry

          icon = DockIcon.new(app_entry: app_entry)
          icon.dock = self
          @icons << icon
          @icon_box.pack_start(icon, expand: false, fill: false, padding: 4)
        end

        # Cache icon center positions after window is shown
        signal_connect_after('map') do
          cache_icon_positions
          false
        end
      end

      def cache_icon_positions
        @icon_centers = []
        box_alloc = @icon_box.allocation
        box_offset_x = box_alloc.x

        @icons.each do |icon|
          icon_alloc = icon.allocation
          center_x = box_offset_x + icon_alloc.x + DockIcon::BASE_SIZE / 2.0 + 4 # +4 for padding
          @icon_centers << center_x
        end
      end

      def setup_events
        add_events(Gdk::EventMask::POINTER_MOTION_MASK |
                   Gdk::EventMask::LEAVE_NOTIFY_MASK |
                   Gdk::EventMask::ENTER_NOTIFY_MASK)

        signal_connect('motion-notify-event') do |widget, _event|
          _window, x, _y, _mask = widget.window.get_device_position(
            Gdk::Display.default.default_seat.pointer
          )
          on_pointer_motion(x)
          false
        end

        signal_connect('enter-notify-event') do |widget, _event|
          _window, x, _y, _mask = widget.window.get_device_position(
            Gdk::Display.default.default_seat.pointer
          )
          on_pointer_motion(x)
          false
        end

        signal_connect('leave-notify-event') do |_widget, event|
          # Only reset if actually leaving the dock (not entering a child)
          if event.detail != Gdk::NotifyType::INFERIOR
            reset_magnification
          end
          false
        end
      end

      def update_magnification(cursor_x)
        return if @icon_centers.empty?

        @icons.each_with_index do |icon, index|
          icon_center_x = @icon_centers[index]

          # Calculate distance from cursor to icon center
          distance = (cursor_x - icon_center_x).abs

          # Calculate scale factor using cosine falloff for smooth effect
          if distance < MAGNIFICATION_RADIUS
            # Cosine falloff: 1.0 at center, 0.0 at edge of radius
            scale = (Math.cos(distance / MAGNIFICATION_RADIUS * Math::PI / 2)) ** 2
            icon.update_scale(scale)
          else
            icon.reset_scale
          end
        end
      end

      def reset_magnification
        @icons.each(&:reset_scale)
      end
    end
  end
end
