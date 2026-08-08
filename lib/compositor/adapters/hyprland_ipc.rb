# frozen_string_literal: true

require 'json'

module Compositor
  module Adapters
    module HyprlandIpc
      module_function

      def workspaces
        output = `hyprctl workspaces -j`.strip
        JSON.parse(output)
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "HyprlandIpc.workspaces: #{e.message}"
        []
      end

      def active_workspace
        output = `hyprctl activeworkspace -j`.strip
        JSON.parse(output)
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "HyprlandIpc.active_workspace: #{e.message}"
        {}
      end

      def monitors
        output = `hyprctl monitors -j`.strip
        JSON.parse(output)
      rescue JSON::ParserError, Errno::ENOENT => e
        warn "HyprlandIpc.monitors: #{e.message}"
        []
      end

      def switch_workspace(workspace_id)
        system("hyprctl dispatch workspace #{workspace_id}")
      end

      def reload
        system('hyprctl', 'reload', out: File::NULL, err: File::NULL)
      end

      def move_workspace_to_monitor(workspace_id, monitor_name)
        system('hyprctl', 'dispatch', 'moveworkspacetomonitor',
               workspace_id.to_s, monitor_name, out: File::NULL, err: File::NULL)
      end
    end
  end
end
