# frozen_string_literal: true

module Portland
  module Domain
    # needed_keyword: what accepting the slot's NEWEST version requires —
    # nil when it's stable, "~<arch>" when testing, "**" when unkeyworded.
    # accepted_by: the package.accept_keywords file already covering this
    # slot, nil when none does. installed_version: nil when not installed.
    SlotOption = Struct.new(:slot, :newest_version, :installed_version,
                            :needed_keyword, :accepted_by, :upgrade_available,
                            keyword_init: true) do
      def installed
        !installed_version.nil?
      end
    end
  end
end
