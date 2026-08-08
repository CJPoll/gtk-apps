# frozen_string_literal: true

module Portland
  module Managers
    # Loads a package's detail panel data (slot options and USE flags) off
    # the main loop, once per atom; rows ask on first expand so search
    # results stay cheap. Invalidated after config changes are installed so
    # re-expansion reflects the new on-disk state.
    class DetailFetcher
      Details = Struct.new(:slots, :use_flags, keyword_init: true)

      def initialize
        @cache = {}
      end

      def fetch(atom, &on_details)
        if (cached = @cache[atom])
          on_details.call(cached)
          return
        end

        Thread.new do
          details = load(atom)

          GLib::Idle.add do
            @cache[atom] = details
            on_details.call(details)
            false
          end
        end
      end

      def invalidate!
        @cache.clear
      end

      private

      def load(atom)
        Details.new(
          slots: Domain::SlotCatalog.build(
            atom,
            Adapters::PortageCli.slot_entries(atom),
            Adapters::PortageCli.installed_slot_versions(atom),
            arch: Adapters::PortageCli.arch,
            keyword_entries: Adapters::PortageCli.keyword_config_entries
          ),
          use_flags: Domain::UseCatalog.build(
            atom,
            iuse: Adapters::PortageCli.package_iuse(atom),
            global_use: Adapters::PortageCli.global_use,
            entries: Adapters::PortageCli.use_config_entries,
            descriptions: Adapters::PortageCli.use_descriptions(atom)
          )
        )
      end
    end
  end
end
