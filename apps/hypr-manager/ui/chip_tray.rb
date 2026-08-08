# frozen_string_literal: true

module HyprManager
  module UI
    # Workspaces not bound to any monitor. Dropping a chip here unbinds it.
    class ChipTray < Gtk::Box
      def initialize(workspace_ids, on_unassign:)
        super(:horizontal, 6)
        @on_unassign = on_unassign

        add_css_class('chip-tray')

        label = Gtk::Label.new('Unassigned workspaces:')
        label.add_css_class('chip-tray-label')
        append(label)

        if workspace_ids.empty?
          hint = Gtk::Label.new('none — drop a chip here to unbind it')
          hint.add_css_class('chip-hint')
          append(hint)
        else
          workspace_ids.each do |workspace_id|
            append(WorkspaceChip.new(workspace_id))
          end
        end

        target = Gtk::DropTarget.new(DragPayload::STRING_TYPE, :move)
        target.signal_connect('drop') do |_target, value, _x, _y|
          kind, payload = DragPayload.decode_drop(value)
          if kind == :workspace
            @on_unassign.call(payload)
            true
          else
            false
          end
        end
        add_controller(target)
      end
    end
  end
end
