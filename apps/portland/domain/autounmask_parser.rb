# frozen_string_literal: true

module Portland
  module Domain
    # Parses `emerge --pretend --autounmask` output into the config changes
    # emerge declared necessary. Only the keyword and USE sections are
    # config-file entries portland can stage; other sections (license,
    # package.unmask) are currently ignored.
    module AutounmaskParser
      SECTION_STARTS = {
        'The following keyword changes are necessary to proceed' => :keyword,
        'The following USE changes are necessary to proceed' => :use
      }.freeze

      ENTRY = %r{\A[<>=~]*[\w.+-]+/\S+\s+\S}

      def self.parse(output)
        changes = []
        kind = nil
        required_by = []

        output.each_line do |raw|
          line = raw.chomp

          if (new_kind = section_for(line))
            kind = new_kind
            required_by = []
            next
          end

          next unless kind

          case line
          when /\A\s*\(see "/ then next
          when /\A#\s*required by (.+)\z/
            required_by << Regexp.last_match(1)
          when ENTRY
            atom_spec, *tokens = line.split
            changes << SuggestedChange.new(kind: kind, atom_spec: atom_spec,
                                           tokens: tokens, required_by: required_by)
            required_by = []
          when /\A\s*\z/
            next
          else
            # Anything else ends the section (totals, notes, next heading).
            kind = nil
            required_by = []
          end
        end

        changes
      end

      def self.section_for(line)
        SECTION_STARTS.each do |prefix, kind|
          return kind if line.start_with?(prefix)
        end
        nil
      end

      UNSATISFIABLE = /\Aemerge: there are no ebuilds to satisfy "([^"]+)"\.?\z/

      # USE flags demanded by dependency specs emerge declared unsatisfiable,
      # e.g. `>=dev-ruby/rake-13.2.1[ruby_targets_ruby34(-)]` -> the flag.
      # These are the candidates for a profile stable-mask override.
      def self.unsatisfiable_flags(output)
        output.each_line.flat_map do |line|
          match = UNSATISFIABLE.match(line.strip)
          next [] unless match

          use_deps = match[1][/\[([^\]]+)\]/, 1]
          next [] unless use_deps

          use_deps.split(',').map { |dep| dep.strip.sub(/\([-+]\)\z/, '').delete_prefix('-').delete_prefix('!') }
        end.uniq
      end

      # Unsatisfied soft blocks: "[blocks B ] <sys-apps/shadow-4.19.0_rc1 (...)".
      # The fix is upgrading the blocking package in the same transaction, so
      # the blocker's bare atom is the actionable output. Lowercase b blocks
      # are already satisfied and need nothing.
      BLOCK_LINE = %r{\A\[blocks B\s*\]\s+([^\s(]+)}

      def self.soft_blockers(output)
        output.each_line.filter_map do |line|
          match = BLOCK_LINE.match(line)
          next unless match

          match[1].sub(/\A[<>=~!]+/, '').sub(%r{-\d[^/]*\z}, '')
        end.uniq
      end

      ERROR_MARKERS = [
        'emerge: there are no ebuilds',
        '!!! All ebuilds that could satisfy',
        '!!! Multiple package instances',
        '[blocks B'
      ].freeze
      ERROR_CONTEXT_LINES = 14

      # The failure paragraphs, for surfacing verbatim when resolution can't
      # be fixed by config changes portland knows how to stage. Each marker
      # captures a bounded block of context (mask reasons, dependency
      # chains, slot-conflict participants).
      def self.resolution_error(output)
        lines = output.lines.map(&:chomp)
        blocks = []
        last_end = -1

        lines.each_with_index do |line, index|
          next if index <= last_end
          next unless ERROR_MARKERS.any? { |marker| line.start_with?(marker) }

          block = lines[index, ERROR_CONTEXT_LINES]
          cutoff = block.index { |l| l.start_with?('NOTE:', 'For more information') }
          block = block[0...cutoff] if cutoff
          last_end = index + block.size - 1

          blocks << block.join("\n").strip
        end

        blocks.empty? ? nil : blocks.join("\n\n")
      end
    end
  end
end
