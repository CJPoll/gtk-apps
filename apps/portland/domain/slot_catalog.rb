# frozen_string_literal: true

module Portland
  module Domain
    # Groups a package's available versions by SLOT: newest version,
    # installed version, upgrade availability, and keyword standing per
    # slot. Subslots ("0/2.30") collapse to their main slot — that's the
    # part an install atom names. Live (9999) ebuilds are hidden: they're
    # keyword-masked by default and would otherwise always claim "newest".
    module SlotCatalog
      # versions: [{version:, slot:, keywords:}, ...] from the metadata cache
      # installed_versions: {slot => version} from the installed-package db
      # keyword_entries: ConfigEntry list from package.accept_keywords files
      def self.build(atom, versions, installed_versions, arch:, keyword_entries: [])
        installed = installed_versions.to_h { |slot, version| [main_slot(slot), version] }

        versions
          .reject { |entry| entry[:version].include?('9999') }
          .group_by { |entry| main_slot(entry[:slot]) }
          .map do |slot, entries|
            newest = entries.max_by { |e| version_key(e[:version]) }
            installed_version = installed[slot]

            SlotOption.new(
              slot: slot,
              newest_version: newest[:version],
              installed_version: installed_version,
              needed_keyword: needed_keyword(newest, arch),
              accepted_by: keyword_entries.find { |e| e.matches?(atom, slot: slot) }&.file,
              upgrade_available: upgrade?(installed_version, newest[:version])
            )
          end
          .sort_by { |option| version_key(option.slot) }
      end

      def self.main_slot(slot)
        slot.split('/').first
      end

      # Keyword standing of the newest version — the one an install or
      # upgrade of this slot would actually pull.
      def self.needed_keyword(entry, arch)
        keywords = entry[:keywords].to_s.split
        return nil if keywords.include?(arch)
        return "~#{arch}" if keywords.include?("~#{arch}")

        '**'
      end

      def self.upgrade?(installed_version, newest_version)
        return false unless installed_version

        (version_key(newest_version) <=> version_key(installed_version)).positive?
      end

      # Orders by numeric runs, then letter suffixes ("3.5a" > "3.5",
      # "3.7b" > "3.7a"). Not a full Gentoo comparison (_pre/_p treated as
      # plain segments) but right for display and upgrade detection.
      def self.version_key(version)
        version.scan(/\d+|[a-z]+/).map do |part|
          part.match?(/\d/) ? [1, part.to_i, ''] : [0, 0, part]
        end
      end
    end
  end
end
