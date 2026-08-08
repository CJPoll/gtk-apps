# frozen_string_literal: true

module Portland
  module Domain
    # One config entry emerge's autounmask says is necessary: kind is
    # :keyword (package.accept_keywords) or :use (package.use), atom_spec and
    # tokens are exactly as emerge printed them, required_by is the
    # dependency chain from the "# required by" comments above the entry.
    SuggestedChange = Struct.new(:kind, :atom_spec, :tokens, :required_by,
                                 keyword_init: true) do
      def to_line
        "#{atom_spec} #{tokens.join(' ')}"
      end
    end
  end
end
