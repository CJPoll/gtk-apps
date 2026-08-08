# frozen_string_literal: true

module Bar
  module UI
    class WorkspacesWidget < Gtk::Box
      include GtkKit::Timers

      UPDATE_INTERVAL_SECONDS = 1
      PULSE_INTERVAL_MS = 750

      def initialize(monitor_name:)
        super(:horizontal, 0)

        @monitor_name = monitor_name
        @buttons = {}
        @pulse_state = false

        add_css_class('workspaces')
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
          next unless button.has_css_class?('urgent')

          if @pulse_state
            button.add_css_class('pulse-bright')
          else
            button.remove_css_class('pulse-bright')
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
            remove(@buttons[id])
            @buttons.delete(id)
          end
        end

        # Add or update buttons
        workspaces.each do |workspace|
          if @buttons[workspace.id]
            update_button(@buttons[workspace.id], workspace)
          else
            @buttons[workspace.id] = create_button(workspace)
          end
        end

        # Walk the desired order, moving each button after the previous one.
        previous = nil
        workspaces.each do |workspace|
          button = @buttons[workspace.id]
          next unless button

          reorder_child_after(button, previous)
          previous = button
        end
      end

      def create_button(workspace)
        button = Gtk::Button.new(label: workspace.display_name)
        button.add_css_class('pill')
        button.add_css_class('workspace-button')

        update_button_state(button, workspace)

        button.signal_connect('clicked') do
          Compositor::Adapters::HyprlandIpc.switch_workspace(workspace.id)
        end

        append(button)
        button
      end

      def update_button(button, workspace)
        button.label = workspace.display_name
        update_button_state(button, workspace)
      end

      def update_button_state(button, workspace)
        if workspace.active
          button.add_css_class('active')
        else
          button.remove_css_class('active')
        end

        if workspace.urgent
          button.add_css_class('urgent')
        else
          button.remove_css_class('urgent')
        end
      end
    end
  end
end
