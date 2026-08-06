# frozen_string_literal: true

module Bar
  module UI
    class WorkspacesWidget < Gtk::Box
      include WidgetTimers

      UPDATE_INTERVAL_SECONDS = 1
      PULSE_INTERVAL_MS = 750

      def initialize(monitor_name:)
        super(:horizontal, 0)

        @monitor_name = monitor_name
        @buttons = {}
        @pulse_state = false

        style_context.add_class('workspaces')
        setup_ui
        start_timer
        start_pulse_timer
      end

      private

      def setup_ui
        update_workspaces
      end

      def start_timer
        every_seconds(UPDATE_INTERVAL_SECONDS) { update_workspaces }
      end

      def start_pulse_timer
        every_ms(PULSE_INTERVAL_MS) do
          @pulse_state = !@pulse_state
          update_pulse_states
        end
      end

      def update_pulse_states
        @buttons.each_value do |button|
          style = button.style_context
          next unless style.has_class?('urgent')

          if @pulse_state
            style.add_class('pulse-bright')
          else
            style.remove_class('pulse-bright')
          end
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
