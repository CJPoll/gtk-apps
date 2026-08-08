# frozen_string_literal: true

module HyprManager
  module UI
    # One in-app drag target; payloads are tagged strings so a drop site can
    # tell a workspace chip from a monitor card.
    module DragPayload
      TARGETS = [['text/plain', Gtk::TargetFlags::SAME_APP, 0]].freeze

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
    end
  end
end
