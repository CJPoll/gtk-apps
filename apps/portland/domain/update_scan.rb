# frozen_string_literal: true

module Portland
  module Domain
    # Finds slots whose installed version is older than the best version
    # VISIBLE under the current keyword configuration: stable versions
    # always, testing versions only when an accept_keywords entry covers
    # the package/slot. Deliberately not a dependency resolution — it
    # answers "is something newer available to me", per package; whether an
    # upgrade's dependencies work out is the resolver's job at Apply time.
    module UpdateScan
      # -> [{slot:, from:, to:}, ...]
      def self.updates_for(atom, version_entries, installed_versions, arch:, keyword_entries: [])
        installed_versions.filter_map do |slot, installed|
          slot = SlotCatalog.main_slot(slot)

          best = version_entries
                 .select { |e| SlotCatalog.main_slot(e[:slot]) == slot }
                 .reject { |e| e[:version].include?('9999') }
                 .select { |e| visible?(e, atom, slot, arch, keyword_entries) }
                 .max_by { |e| SlotCatalog.version_key(e[:version]) }
          next unless best

          newer = (SlotCatalog.version_key(best[:version]) <=>
                   SlotCatalog.version_key(installed)).positive?
          { slot: slot, from: installed, to: best[:version] } if newer
        end
      end

      def self.visible?(entry, atom, slot, arch, keyword_entries)
        keywords = entry[:keywords].to_s.split
        return true if keywords.include?(arch)
        return false unless keywords.include?("~#{arch}")

        keyword_entries.any? { |e| e.matches?(atom, slot: slot) }
      end
    end
  end
end
