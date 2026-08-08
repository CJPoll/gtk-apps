# frozen_string_literal: true

module Launcher
  module UI
    class Dock < Gtk::Box
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
      # Height of the dock area to accommodate max icon size extending above
      DOCK_HEIGHT = DockIcon::MAX_SIZE + 24

      def initialize
        super(:horizontal, 0)

        @icons = []
        @icon_centers = [] # Cached center positions

        # Fixed height container to prevent jitter
        set_size_request(-1, DOCK_HEIGHT)
        set_valign(:end)

        # Use overlay so icons can extend above the background
        @overlay = Gtk::Overlay.new
        @overlay.set_halign(:center)
        @overlay.set_valign(:end)
        @overlay.hexpand = true

        # Background container (full height, transparent)
        @bg_container = Gtk::Box.new(:vertical, 0)
        @bg_container.set_valign(:end)

        # Visual background (styled, fixed height at bottom). GTK4 boxes
        # pack from the start, so an expanding spacer above the background
        # pins it to the container's bottom edge — GTK3's pack_end.
        spacer = Gtk::Box.new(:vertical, 0)
        spacer.vexpand = true
        @bg_container.append(spacer)

        @background = Gtk::Box.new(:horizontal, 0)
        @background.add_css_class('dock-background')
        @background.set_size_request(-1, DOCK_BOX_HEIGHT)
        @background.vexpand = false
        @bg_container.append(@background)

        @overlay.child = @bg_container

        # Icon container (overlaid, can extend above background)
        @icon_box = Gtk::Box.new(:horizontal, 8)
        @icon_box.add_css_class('dock-icons')
        @icon_box.set_halign(:center)
        @icon_box.set_valign(:end)
        @overlay.add_overlay(@icon_box)

        append(@overlay)

        setup_icons
        setup_events
        lock_geometry_after_map
      end

      def on_pointer_motion(cursor_x)
        update_magnification(cursor_x)
      end

      private

      def setup_icons
        DOCK_APPS.each do |app_name|
          app_entry = Domain::AppEntry.from_desktop_file(app_name)
          next unless app_entry

          icon = DockIcon.new(app_entry: app_entry)
          @icons << icon
          icon.margin_start = 4
          icon.margin_end = 4
          @icon_box.append(icon)
        end
      end

      # Lock the icon box width to its initial size so magnification does not
      # re-center the row (jitter), and cache icon centers for the falloff
      # curve. Runs one idle cycle after map, once the first layout has sizes.
      def lock_geometry_after_map
        signal_connect_after('map') do
          GLib::Idle.add do
            alloc = @icon_box.allocation
            if alloc.width.positive?
              @icon_box.set_size_request(alloc.width, -1)
              @background.set_size_request(alloc.width, DOCK_BOX_HEIGHT)
              @bg_container.set_size_request(alloc.width, DOCK_HEIGHT)
              cache_icon_positions
            end
            false
          end
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

      # One motion controller on the dock covers every child icon: GTK4
      # delivers coordinates relative to this widget and treats the pointer
      # as inside until it leaves the dock's whole subtree.
      def setup_events
        motion = Gtk::EventControllerMotion.new
        motion.signal_connect('enter') { |_c, x, _y| on_pointer_motion(x) }
        motion.signal_connect('motion') { |_c, x, _y| on_pointer_motion(x) }
        motion.signal_connect('leave') { reset_magnification }
        add_controller(motion)
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
            scale = (Math.cos(distance / MAGNIFICATION_RADIUS * Math::PI / 2))**2
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
