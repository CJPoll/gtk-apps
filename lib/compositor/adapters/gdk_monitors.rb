# frozen_string_literal: true

module Compositor
  module Adapters
    # Bridges Hyprland monitor names to GDK monitor handles. The two APIs share
    # no identifier, so they are matched on screen position.
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

      def find_by_position(x_position, y_position)
        display = Gdk::Display.default
        return nil unless display

        monitors = display.monitors
        monitors.n_items.times do |index|
          monitor = monitors.get_item(index)
          geometry = monitor.geometry

          return monitor if geometry.x == x_position && geometry.y == y_position
        end

        nil
      end
    end
  end
end
