# frozen_string_literal: true

module HyprManager
  module UI
    # In-app drag payloads are tagged strings so a drop site can tell a
    # workspace chip from a monitor card.
    module DragPayload
      # The GType drag sources offer and drop targets accept.
      STRING_TYPE = GLib::Type['gchararray']

      def self.workspace(workspace_id)
        "ws:#{workspace_id}"
      end

      def self.monitor(description)
        "mon:#{description}"
      end

      # -> [:workspace, id] | [:monitor, description] | nil
      def self.decode(text)
        case text
        when /\Aws:(\d+)\z/ then [:workspace, Regexp.last_match(1).to_i]
        when /\Amon:(.+)\z/m then [:monitor, Regexp.last_match(1)]
        end
      end

      # Unwraps a GtkDropTarget drop value (GValue or already-converted
      # String, depending on binding version) before decoding.
      def self.decode_drop(value)
        text = value.is_a?(GLib::Value) ? value.value.to_s : value.to_s
        decode(text)
      end
    end
  end
end
