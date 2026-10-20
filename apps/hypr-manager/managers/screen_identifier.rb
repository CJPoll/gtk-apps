# frozen_string_literal: true

module HyprManager
  module Managers
    # Puts a big "this is display N" overlay on one physical monitor so the
    # user can tell which card in the strip is which screen.
    #
    # Cards are identified by EDID description, never by port name: the port
    # on the card may be stale after a re-enumeration, so the live connector is
    # re-resolved from hyprctl on every click. Hyprland and GDK share no
    # identifier except the connector name (Wayland GDK reports it), with
    # screen position as the fallback bridge. The label is built from the live
    # monitor, not the card's, so it shows what the compositor reports now
    # (the card may carry unsaved mode edits).
    #
    # Collaborators are injected: ipc answers #monitors (hyprctl json), gdk
    # answers #find_by_connector / #find_by_position, and overlay_maker is
    # called with (label, gdk_monitor) and returns something that responds to
    # #close, or nil when overlays can't be pinned to an output.
    class ScreenIdentifier
      def initialize(overlay_maker:, ipc: Compositor::Adapters::HyprlandIpc,
                     gdk: Compositor::Adapters::GdkMonitors)
        @ipc = ipc
        @gdk = gdk
        @overlay_maker = overlay_maker
        @overlays = {}
      end

      # position is the monitor's zero-based slot in the layout. Returns
      # :shown, :not_connected, :no_output or :unsupported.
      def identify(monitor, position:)
        live = live_monitor(monitor.description)
        return :not_connected unless live

        gdk_monitor = @gdk.find_by_connector(live['name']) || @gdk.find_by_position(live['x'], live['y'])
        return :no_output unless gdk_monitor

        label = Domain::IdentifyLabel.for(Domain::Monitor.from_hyprctl(live), position: position)
        overlay = @overlay_maker.call(label, gdk_monitor)
        return :unsupported unless overlay

        # One overlay per monitor: a second click replaces rather than stacks.
        @overlays.delete(monitor.description)&.close
        @overlays[monitor.description] = overlay
        :shown
      end

      def close_all
        @overlays.each_value(&:close)
        @overlays.clear
      end

      private

      def live_monitor(description)
        @ipc.monitors.find { |data| data['description'] == description && !data['disabled'] }
      end
    end
  end
end
