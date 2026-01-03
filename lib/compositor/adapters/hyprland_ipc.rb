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
    end
  end
end
