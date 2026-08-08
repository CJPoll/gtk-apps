# frozen_string_literal: true

module Portland
  module Domain
    SlotOption = Struct.new(:slot, :newest_version, :installed, keyword_init: true)
  end
end
