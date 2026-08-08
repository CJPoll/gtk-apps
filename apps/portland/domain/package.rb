# frozen_string_literal: true

module Portland
  module Domain
    # note: optional short annotation shown as a badge (e.g. "3.5a → 3.6a"
    # in the updates view); its presence also marks the package upgradable.
    Package = Struct.new(:atom, :description, :installed, :note, keyword_init: true)
  end
end
