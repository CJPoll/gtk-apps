# frozen_string_literal: true

module Portland
  module Domain
    # Parses qsearch output ("category/name: description" lines) into Packages.
    # Name and description searches run as separate qsearch passes, so the
    # combined output can repeat an atom; first occurrence wins.
    module SearchResultParser
      LINE = %r{\A([\w.+-]+/[\w.+-]+):\s*(.*)\z}

      def self.parse(output, installed_atoms)
        installed = installed_atoms.to_h { |atom| [atom, true] }
        packages = {}

        output.each_line do |line|
          match = LINE.match(line.strip)
          next unless match

          atom = match[1]
          next if packages.key?(atom)

          packages[atom] = Package.new(
            atom: atom,
            description: match[2],
            installed: installed.fetch(atom, false)
          )
        end

        packages.values.sort_by(&:atom)
      end
    end
  end
end
