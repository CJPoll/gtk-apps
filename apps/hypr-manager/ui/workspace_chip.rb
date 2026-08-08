# frozen_string_literal: true

module HyprManager
  module UI
    # A draggable workspace number; drop it on a monitor card to bind the
    # workspace there, or on the tray to unbind it.
    class WorkspaceChip < Gtk::EventBox
      def initialize(workspace_id)
        super()
        @workspace_id = workspace_id

        label = Gtk::Label.new(workspace_id.to_s)
        label.style_context.add_class('workspace-chip')
        add(label)

        drag_source_set(Gdk::ModifierType::BUTTON1_MASK,
                        DragPayload::TARGETS, Gdk::DragAction::MOVE)
        signal_connect('drag-data-get') do |_widget, _context, data, _info, _time|
          data.text = DragPayload.workspace(@workspace_id)
        end
      end
    end
  end
end
