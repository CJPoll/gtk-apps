# frozen_string_literal: true

require 'shellwords'

module Portland
  module Adapters
    # Read-only portage queries via portage-utils. Anything that mutates the
    # system goes through Terminal instead, where the user can authorize it.
    module PortageCli
      module_function

      # qsearch treats name search (-s) and description search (-S) as
      # separate modes, so run both; the parser dedups overlapping atoms.
      def search(query)
        escaped = Shellwords.escape(query)
        names = `qsearch -s -- #{escaped} 2>/dev/null`
        descriptions = `qsearch -S -- #{escaped} 2>/dev/null`
        names + descriptions
      rescue Errno::ENOENT
        ''
      end

      def installed_atoms
        `qlist -I 2>/dev/null`.split("\n")
      rescue Errno::ENOENT
        []
      end

      # Installed slots for one package, e.g. ["3.3", "3.2"].
      def installed_slots(atom)
        `qlist -IS #{Shellwords.escape(atom)} 2>/dev/null`
          .split("\n")
          .filter_map { |line| line.split(':', 2)[1] }
      rescue Errno::ENOENT
        []
      end

      # [version, slot] pairs for every available version of a package, read
      # from each repo's pregenerated metadata cache (which has SLOT already
      # resolved — no ebuild sourcing). Overlays without a metadata/md5-cache
      # directory simply contribute nothing.
      def slot_entries(atom)
        category, name = atom.split('/', 2)
        return [] unless category && name

        md5_cache_dirs.flat_map do |dir|
          Dir.glob(File.join(dir, category, "#{name}-*")).filter_map do |path|
            version = File.basename(path).delete_prefix("#{name}-")
            next unless version.match?(/\A\d/)

            slot_line = File.foreach(path).find { |line| line.start_with?('SLOT=') }
            next unless slot_line

            [version, slot_line.chomp.delete_prefix('SLOT=')]
          end
        end
      end

      def md5_cache_dirs
        @md5_cache_dirs ||= repo_paths.filter_map do |repo_path|
          dir = File.join(repo_path, 'metadata', 'md5-cache')
          dir if File.directory?(dir)
        end
      end

      def repo_paths
        repos = `portageq get_repos / 2>/dev/null`.split
        return [] if repos.empty?

        `portageq get_repo_path / #{repos.join(' ')} 2>/dev/null`.split("\n")
      rescue Errno::ENOENT
        []
      end
    end
  end
end
