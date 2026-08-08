# frozen_string_literal: true

module Portland
  module Domain
    # One line of a /etc/portage/package.* file: which file it came from,
    # the atom spec as written, and its tokens (flags or keywords).
    ConfigEntry = Struct.new(:file, :atom_spec, :tokens, keyword_init: true) do
      # "=net-wireless/bluetui-0.6::lamdness" -> "net-wireless/bluetui"
      def category_package
        spec = atom_spec.sub(/\A[<>=~!]+/, '')
        spec = spec.split(':', 2).first
        spec.sub(/-\d[^\/]*\z/, '')
      end

      # nil when the spec names no slot
      def slot
        rest = atom_spec.split(':', 2)[1]
        rest&.split(/[:\/]/)&.first
      end

      def matches?(atom, slot: nil)
        target_pkg, target_slot = atom.split(':', 2)
        target_slot = slot if slot
        return false unless category_package == target_pkg

        self.slot.nil? || target_slot.nil? || self.slot == target_slot
      end
    end
  end
end
