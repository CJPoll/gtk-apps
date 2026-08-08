# frozen_string_literal: true

module Portland
  module Domain
    # Groups a package's available versions by SLOT: newest version, installed
    # state, and keyword standing per slot. Subslots ("0/2.30") collapse to
    # their main slot — that's the part an install atom names. Live (9999)
    # ebuilds are hidden: they're keyword-masked by default and would
    # otherwise always claim "newest".
    module SlotCatalog
      # versions: [{version:, slot:, keywords:}, ...] from the metadata cache
      # keyword_entries: ConfigEntry list from package.accept_keywords files
      def self.build(atom, versions, installed_slots, arch:, keyword_entries: [])
        installed = installed_slots.map { |slot| main_slot(slot) }

        versions
          .reject { |entry| entry[:version].include?('9999') }
          .group_by { |entry| main_slot(entry[:slot]) }
          .map do |slot, entries|
            SlotOption.new(
              slot: slot,
              newest_version: entries.map { |e| e[:version] }.max_by { |v| version_key(v) },
              installed: installed.include?(slot),
              needed_keyword: needed_keyword(entries, arch),
              accepted_by: keyword_entries.find { |e| e.matches?(atom, slot: slot) }&.file
            )
          end
          .sort_by { |option| version_key(option.slot) }
      end

      def self.main_slot(slot)
        slot.split('/').first
      end

      def self.needed_keyword(entries, arch)
        keyword_sets = entries.map { |e| e[:keywords].to_s.split }
        return nil if keyword_sets.any? { |set| set.include?(arch) }
        return "~#{arch}" if keyword_sets.any? { |set| set.include?("~#{arch}") }

        '**'
      end

      # Good enough for ordering display rows; not a full Gentoo version
      # comparison (suffixes like _pre/_p are ignored).
      def self.version_key(version)
        version.scan(/\d+/).map(&:to_i)
      end
    end
  end
end
