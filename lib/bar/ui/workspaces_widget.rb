# frozen_string_literal: true

module Bar
  module UI
    class WorkspacesWidget < Gtk::Box
      UPDATE_INTERVAL_SECONDS = 1

      def initialize(monitor_name:)
        super(:horizontal, 0)

        @monitor_name = monitor_name
        @buttons = {}

        style_context.add_class('workspaces')
        setup_ui
        start_timer
      end

      private

      def setup_ui
        update_workspaces
      end

      def start_timer
        GLib::Timeout.add_seconds(UPDATE_INTERVAL_SECONDS) do
          update_workspaces
          true # Continue timer
        end
      end

      def update_workspaces
        workspaces_data = Compositor::Adapters::HyprlandIpc.workspaces
        active_data = Compositor::Adapters::HyprlandIpc.active_workspace
        active_id = active_data['id']

        workspaces = workspaces_data
          .select { |ws| ws['monitor'] == @monitor_name }
          .map { |ws| Compositor::Domain::Workspace.from_hyprland(ws, active_id: active_id) }
          .sort_by(&:id)

        rebuild_buttons(workspaces)
      end

      def rebuild_buttons(workspaces)
        current_ids = workspaces.map(&:id)

        # Remove buttons for workspaces that no longer exist
        @buttons.keys.each do |id|
          unless current_ids.include?(id)
            @buttons[id].destroy
            @buttons.delete(id)
          end
        end

        # Add or update buttons
        workspaces.each_with_index do |workspace, index|
          if @buttons[workspace.id]
            update_button(@buttons[workspace.id], workspace)
          else
            button = create_button(workspace)
            @buttons[workspace.id] = button
            reorder_child(button, index)
          end
        end

        # Reorder all buttons to match workspace order
        workspaces.each_with_index do |workspace, index|
          button = @buttons[workspace.id]
          reorder_child(button, index) if button
        end

        show_all
      end

      def create_button(workspace)
        button = Gtk::Button.new(label: workspace.display_name)
        button.style_context.add_class('pill')
        button.style_context.add_class('workspace-button')

        update_button_state(button, workspace)

        button.signal_connect('clicked') do
          Compositor::Adapters::HyprlandIpc.switch_workspace(workspace.id)
        end

        pack_start(button, expand: false, fill: false, padding: 0)
        button
      end

      def update_button(button, workspace)
        button.label = workspace.display_name
        update_button_state(button, workspace)
      end

      def update_button_state(button, workspace)
        style = button.style_context

        if workspace.active
          style.add_class('active')
        else
          style.remove_class('active')
        end

        if workspace.urgent
          style.add_class('urgent')
        else
          style.remove_class('urgent')
        end
      end
    end
  end
end
