# frozen_string_literal: true

module Portland
  module Domain
    # Parses and renders /etc/portage/package.* file contents.
    module ConfigFileFormat
      def self.parse(content, file:)
        content.each_line.filter_map do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')

          atom_spec, *tokens = line.split
          next if tokens.empty?

          ConfigEntry.new(file: file, atom_spec: atom_spec, tokens: tokens)
        end
      end

      def self.render(entries, header:)
        lines = ["# #{header}", '# Managed by portland; manual edits may be overwritten.', '']
        entries.sort_by(&:atom_spec).each do |entry|
          lines << "#{entry.atom_spec} #{entry.tokens.join(' ')}"
        end
        "#{lines.join("\n")}\n"
      end
    end
  end
end
