# frozen_string_literal: true

module HyprManager
  module Domain
    # Hyprland's `workspace = N, monitor:...` rules bind only when a
    # workspace is created; a reload never relocates one that already
    # exists. This decides which live workspaces need an explicit
    # moveworkspacetomonitor dispatch after a save. Pure: live state and
    # the description->port mapping are passed in.
    module WorkspaceMoves
      module_function

      # assignments:     {workspace_id => monitor description}
      # monitor_names:   {monitor description => port name (e.g. "DP-4")}
      # live_workspaces: hyprctl workspaces -j shape ({'id', 'monitor', ...})
      #
      # -> [[workspace_id, port_name], ...] for workspaces that exist and
      # sit on a monitor other than their assigned one. Workspaces not
      # currently alive are skipped — dispatching a move would materialize
      # them, and the creation-time rule already covers their next use.
      def needed(assignments, monitor_names:, live_workspaces:)
        current = live_workspaces.to_h { |workspace| [workspace['id'], workspace['monitor']] }

        assignments.filter_map do |workspace_id, description|
          name = monitor_names[description]
          next unless name
          next unless current.key?(workspace_id)
          next if current[workspace_id] == name

          [workspace_id, name]
        end
      end
    end
  end
end
