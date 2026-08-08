# frozen_string_literal: true

module HyprManager
  module Domain
    # workspace id -> monitor description. Unassigned workspaces follow
    # hyprland's own placement.
    class WorkspaceAssignments
      WORKSPACE_IDS = (1..6).to_a.freeze

      def initialize(assignments = {})
        @assignments = assignments
      end

      def assign(workspace_id, description)
        @assignments[workspace_id] = description
      end

      def unassign(workspace_id)
        @assignments.delete(workspace_id)
      end

      def monitor_for(workspace_id)
        @assignments[workspace_id]
      end

      def workspaces_on(description)
        @assignments.select { |_, desc| desc == description }.keys.sort
      end

      def unassigned
        WORKSPACE_IDS - @assignments.keys
      end

      def to_h
        @assignments.dup
      end

      def config_lines
        @assignments.sort.map do |workspace_id, description|
          "workspace = #{workspace_id}, monitor:desc:#{description}"
        end
      end
    end
  end
end
