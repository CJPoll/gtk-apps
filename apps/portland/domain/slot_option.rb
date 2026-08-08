# frozen_string_literal: true

module Portland
  module Domain
    # needed_keyword: nil when a stable version exists, "~<arch>" when the
    # slot is testing-only, "**" when nothing is keyworded for this arch.
    # accepted_by: the package.accept_keywords file already covering this
    # slot, nil when none does.
    SlotOption = Struct.new(:slot, :newest_version, :installed,
                            :needed_keyword, :accepted_by,
                            keyword_init: true)
  end
end
