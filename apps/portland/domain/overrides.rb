# frozen_string_literal: true

module Portland
  module Domain
    # In-memory model of portland's own config files (the zz-portland file in
    # package.use and package.accept_keywords, plus the profile
    # use.stable.mask override file). Toggles edit this model; Apply renders
    # and installs it. Dirty means the model has diverged from what was last
    # loaded from disk.
    class Overrides
      USE_HEADER = 'USE flag overrides'
      KEYWORDS_HEADER = 'Accepted keywords'
      STABLE_UNMASK_HEADER = 'Stable-mask overrides (a leading - removes a profile use.stable.mask entry)'

      def initialize(use_content: '', keywords_content: '', stable_unmask_content: '')
        @use = parse_tokens(use_content)
        @keywords = parse_tokens(keywords_content)
        @stable_unmasks = parse_unmasks(stable_unmask_content)
        @dirty = false
      end

      # value: true (flag), false (-flag), nil (drop the override)
      def set_use(atom, flag, value)
        tokens = (@use[atom] ||= {})
        value.nil? ? tokens.delete(flag) : tokens[flag] = value
        @use.delete(atom) if tokens.empty?
        @dirty = true
      end

      def use_for(atom)
        @use.fetch(atom, {})
      end

      # keyword: e.g. "~amd64", or nil to drop the entry
      def set_keyword(atom, keyword)
        keyword.nil? ? @keywords.delete(atom) : @keywords[atom] = { keyword => true }
        @dirty = true
      end

      def keyword_for(atom)
        @keywords.fetch(atom, {}).keys.first
      end

      # Lifts a profile use.stable.mask entry so the flag becomes usable on
      # stable-keyworded package versions.
      def set_stable_unmask(flag)
        @stable_unmasks[flag] = true
        @dirty = true
      end

      def stable_unmasks
        @stable_unmasks.keys
      end

      def dirty?
        @dirty
      end

      def saved!
        @dirty = false
      end

      def change_count
        @use.values.sum(&:size) + @keywords.size + @stable_unmasks.size
      end

      def render_use
        ConfigFileFormat.render(entries_from(@use, negate: true), header: USE_HEADER)
      end

      def render_keywords
        ConfigFileFormat.render(entries_from(@keywords, negate: false), header: KEYWORDS_HEADER)
      end

      def render_stable_unmask
        lines = ["# #{STABLE_UNMASK_HEADER}", '# Managed by portland; manual edits may be overwritten.', '']
        @stable_unmasks.keys.sort.each { |flag| lines << "-#{flag}" }
        "#{lines.join("\n")}\n"
      end

      private

      def parse_unmasks(content)
        content.each_line.filter_map do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')

          [line.delete_prefix('-'), true]
        end.to_h
      end

      def parse_tokens(content)
        ConfigFileFormat.parse(content, file: 'zz-portland').to_h do |entry|
          tokens = entry.tokens.to_h do |token|
            token.start_with?('-') ? [token[1..], false] : [token, true]
          end
          [entry.atom_spec, tokens]
        end
      end

      def entries_from(atoms, negate:)
        atoms.map do |atom, tokens|
          rendered = tokens.map do |token, enabled|
            negate && !enabled ? "-#{token}" : token
          end
          ConfigEntry.new(file: 'zz-portland', atom_spec: atom, tokens: rendered)
        end
      end
    end
  end
end
