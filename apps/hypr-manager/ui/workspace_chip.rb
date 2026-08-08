# frozen_string_literal: true

module HyprManager
  module UI
    # A draggable workspace number; drop it on a monitor card to bind the
    # workspace there, or on the tray to unbind it.
    class WorkspaceChip < Gtk::Label
      def initialize(workspace_id)
        super()
        @workspace_id = workspace_id

        self.text = workspace_id.to_s
        add_css_class('workspace-chip')

        source = Gtk::DragSource.new
        source.actions = :move
        source.signal_connect('prepare') do |_source, _x, _y|
          Gdk::ContentProvider.new(DragPayload.workspace(@workspace_id))
        end
        add_controller(source)
      end
    end
  end
end
