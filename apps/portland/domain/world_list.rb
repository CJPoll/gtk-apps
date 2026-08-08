# frozen_string_literal: true

module Portland
  module Domain
    # Turns /var/lib/portage/world entries into Packages. The world file
    # lists exactly what was deliberately emerged — dependencies never appear
    # in it. Entries may carry a slot ("dev-lang/ruby:3.4"); the package
    # identity is the bare atom, deduped when multiple slots are selected.
    module WorldList
      def self.build(specs, descriptions: {})
        packages = {}

        specs.each do |spec|
          spec = spec.strip
          next if spec.empty? || spec.start_with?('#', '@')

          atom = spec.split(':', 2).first
          next if packages.key?(atom)

          description = descriptions[atom]
          packages[atom] = Package.new(
            atom: atom,
            description: description || '(no longer installed)',
            installed: !description.nil?
          )
        end

        packages.values.sort_by(&:atom)
      end
    end
  end
end
