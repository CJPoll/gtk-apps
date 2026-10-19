# frozen_string_literal: true

module HyprManager
  module Domain
    # What the "Identify screen" overlay shows on one physical monitor. The
    # number is the display's left-to-right slot (the order of the cards in the
    # strip), so the overlay and its card match at a glance; the port, model
    # and mode are the details a user can cross-check against hyprctl.
    class IdentifyLabel < Struct.new(:number, :port, :model, :detail, keyword_init: true)
      # How long the overlay stays up before it dismisses itself.
      DISPLAY_MS = 2500

      # position is the zero-based index of the monitor in the layout.
      def self.for(monitor, position:)
        new(
          number: position + 1,
          port: monitor.name,
          # Same trim the card header uses.
          model: monitor.description.sub(/\ADell Inc\. /, '').strip,
          detail: monitor.mode_string
        )
      end
    end
  end
end
