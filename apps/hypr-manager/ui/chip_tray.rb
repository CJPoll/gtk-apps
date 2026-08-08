# frozen_string_literal: true

module HyprManager
  module UI
    # Workspaces not bound to any monitor. Dropping a chip here unbinds it.
    class ChipTray < Gtk::EventBox
      def initialize(workspace_ids, on_unassign:)
        super()
        @on_unassign = on_unassign

        row = Gtk::Box.new(:horizontal, 6)
        row.style_context.add_class('chip-tray')

        label = Gtk::Label.new('Unassigned workspaces:')
        label.style_context.add_class('chip-tray-label')
        row.pack_start(label, expand: false, fill: false, padding: 0)

        if workspace_ids.empty?
          hint = Gtk::Label.new('none — drop a chip here to unbind it')
          hint.style_context.add_class('chip-hint')
          row.pack_start(hint, expand: false, fill: false, padding: 0)
        else
          workspace_ids.each do |workspace_id|
            row.pack_start(WorkspaceChip.new(workspace_id), expand: false, fill: false, padding: 0)
          end
        end

        add(row)

        drag_dest_set(Gtk::DestDefaults::ALL, DragPayload::TARGETS, Gdk::DragAction::MOVE)
        signal_connect('drag-data-received') do |_widget, _context, _x, _y, data, _info, _time|
          kind, payload = DragPayload.decode(data.text.to_s)
          @on_unassign.call(payload) if kind == :workspace
        end
      end
    end
  end
end
