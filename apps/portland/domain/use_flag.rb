# frozen_string_literal: true

module Portland
  module Domain
    # One USE flag as shown for a package: its effective state, whether that
    # state comes from an explicit package.use entry (and from which file),
    # and what the state would be with no entry at all.
    UseFlag = Struct.new(:name, :enabled, :default_enabled, :source, :description,
                         keyword_init: true) do
      def overridden?
        !source.nil?
      end
    end
  end
end
