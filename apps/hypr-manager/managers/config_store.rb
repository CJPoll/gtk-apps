# frozen_string_literal: true

module HyprManager
  module Managers
    # Loads editing state (live monitors from hyprctl + assignments seeded
    # from the conf file) and saves it back (write file, hyprctl reload).
    class ConfigStore
      Loaded = Struct.new(:layout, :assignments, :conf, keyword_init: true)

      def load
        monitors = Compositor::Adapters::HyprlandIpc.monitors
                                                    .reject { |data| data['disabled'] }
                                                    .map { |data| Domain::Monitor.from_hyprctl(data) }
        layout = Domain::MonitorLayout.new(monitors)
        conf = Domain::LocalConf.parse(Adapters::LocalConfFile.read)

        Loaded.new(
          layout: layout,
          assignments: Domain::WorkspaceAssignments.new(resolve_binds(conf.workspace_binds, layout)),
          conf: conf
        )
      end

      def save(loaded)
        Adapters::LocalConfFile.write(loaded.conf.render(loaded.layout, loaded.assignments))
        Compositor::Adapters::HyprlandIpc.reload
        apply_workspace_moves(loaded)
      end

      private

      # Reload only re-reads rules; workspaces that already exist stay on
      # their old monitor. Move the ones whose assignment changed.
      def apply_workspace_moves(loaded)
        monitor_names = loaded.layout.monitors.to_h { |m| [m.description, m.name] }
        moves = Domain::WorkspaceMoves.needed(
          loaded.assignments.to_h,
          monitor_names: monitor_names,
          live_workspaces: Compositor::Adapters::HyprlandIpc.workspaces
        )
        moves.each do |workspace_id, monitor_name|
          Compositor::Adapters::HyprlandIpc.move_workspace_to_monitor(workspace_id, monitor_name)
        end
      end

      # Conf refs may be port names (which re-enumerate) or descriptions;
      # binds that match nothing connected are dropped rather than guessed.
      def resolve_binds(binds, layout)
        binds.filter_map do |workspace_id, ref|
          monitor = layout.monitors.find { |m| m.name == ref || m.description == ref }
          [workspace_id, monitor.description] if monitor
        end.to_h
      end
    end
  end
end
