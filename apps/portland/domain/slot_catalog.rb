# frozen_string_literal: true

module Portland
  module Domain
    # Groups a package's available versions by SLOT and marks which slots are
    # installed. Subslots ("0/2.30") collapse to their main slot — that's the
    # part an install atom names. Live (9999) ebuilds are hidden: they're
    # keyword-masked by default and would otherwise always claim "newest".
    module SlotCatalog
      def self.build(version_slot_pairs, installed_slots)
        installed = installed_slots.map { |slot| main_slot(slot) }

        version_slot_pairs
          .reject { |version, _| version.include?('9999') }
          .group_by { |_, slot| main_slot(slot) }
          .map do |slot, pairs|
            SlotOption.new(
              slot: slot,
              newest_version: pairs.map(&:first).max_by { |v| version_key(v) },
              installed: installed.include?(slot)
            )
          end
          .sort_by { |option| version_key(option.slot) }
      end

      def self.main_slot(slot)
        slot.split('/').first
      end

      # Good enough for ordering display rows; not a full Gentoo version
      # comparison (suffixes like _pre/_p are ignored).
      def self.version_key(version)
        version.scan(/\d+/).map(&:to_i)
      end
    end
  end
end
