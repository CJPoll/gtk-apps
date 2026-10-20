# frozen_string_literal: true

module Compositor
  module Adapters
    # Bridges Hyprland monitor names to GDK monitor handles. Wayland GDK
    # reports each output's connector name (the same "DP-2" hyprctl shows), so
    # find_by_connector is the direct bridge; find_by_position matches on
    # logical screen position where the connector is unavailable.
    #
    # GDK enumerates a new output slightly after Hyprland announces it, so a
    # lookup that fails right after a hotplug means "not ready yet", not
    # "no such monitor".
    module GdkMonitors
      module_function

      def find_by_name(name)
        hypr_monitor = HyprlandIpc.monitors.find { |monitor| monitor['name'] == name }
        return nil unless hypr_monitor

        find_by_position(hypr_monitor['x'], hypr_monitor['y'])
      end

      def find_by_connector(connector)
        all.find { |monitor| monitor.connector == connector }
      end

      def find_by_position(x_position, y_position)
        all.find do |monitor|
          geometry = monitor.geometry
          geometry.x == x_position && geometry.y == y_position
        end
      end

      def all
        display = Gdk::Display.default
        return [] unless display

        monitors = display.monitors
        Array.new(monitors.n_items) { |index| monitors.get_item(index) }
      end
    end
  end
end
