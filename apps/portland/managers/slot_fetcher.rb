# frozen_string_literal: true

module Portland
  module Managers
    # Loads a package's slot options off the main loop, once per atom; rows
    # ask on first expand so search results stay cheap.
    class SlotFetcher
      def initialize
        @cache = {}
      end

      def fetch(atom, &on_slots)
        if (cached = @cache[atom])
          on_slots.call(cached)
          return
        end

        Thread.new do
          entries = Adapters::PortageCli.slot_entries(atom)
          installed = Adapters::PortageCli.installed_slots(atom)
          options = Domain::SlotCatalog.build(entries, installed)

          GLib::Idle.add do
            @cache[atom] = options
            on_slots.call(options)
            false
          end
        end
      end
    end
  end
end
