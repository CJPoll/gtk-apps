# frozen_string_literal: true

module Portland
  module Domain
    Package = Struct.new(:atom, :description, :installed, keyword_init: true)
  end
end
