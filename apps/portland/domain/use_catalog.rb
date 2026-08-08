# frozen_string_literal: true

module Portland
  module Domain
    # Resolves a package's IUSE into displayable UseFlags.
    #
    # Effective state per flag, closest to how portage stacks it:
    #   1. package.use entries across all files, sorted by filename, last
    #      match wins (this is why portland writes to "zz-portland")
    #   2. else the IUSE default (+flag)
    #   3. else membership in the profile/make.conf USE set
    #
    # This is a display model, not a full profile resolution (USE_EXPAND
    # groups and profile package.use forcing are not consulted).
    module UseCatalog
      def self.build(atom, iuse:, global_use:, entries:, descriptions: {})
        relevant = entries.select { |entry| entry.matches?(atom) }
                          .sort_by(&:file)

        parse_iuse(iuse).map do |name, default_on|
          enabled, source = resolve(name, relevant)
          default = default_on || global_use.include?(name)

          UseFlag.new(
            name: name,
            enabled: enabled.nil? ? default : enabled,
            default_enabled: default,
            source: source,
            description: descriptions[name]
          )
        end.sort_by(&:name)
      end

      def self.parse_iuse(iuse)
        iuse.split.map do |token|
          token.start_with?('+') ? [token[1..], true] : [token.delete_prefix('-'), false]
        end
      end

      def self.resolve(name, entries)
        state = nil
        source = nil

        entries.each do |entry|
          entry.tokens.each do |token|
            next unless token == name || token == "-#{name}"

            state = !token.start_with?('-')
            source = entry.file
          end
        end

        [state, source]
      end
    end
  end
end
