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
      end

      private

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
