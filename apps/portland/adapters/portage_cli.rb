# frozen_string_literal: true

require 'set'
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

      # Dry-run resolution with autounmask, as the invoking user (pretend
      # needs no root). Slow — seconds with backtracking — so callers run it
      # off the main loop. configroot points emerge at a sandbox copy of
      # /etc/portage so staged-but-uninstalled config participates.
      def pretend_install(atoms, configroot: nil)
        escaped = atoms.map { |atom| Shellwords.escape(atom) }.join(' ')
        env = configroot ? "PORTAGE_CONFIGROOT=#{Shellwords.escape(configroot)} " : ''
        `#{env}emerge --pretend --autounmask=y --autounmask-use=y --autounmask-backtrack=y --color=n --nospinner #{escaped} 2>&1`
      rescue Errno::ENOENT
        ''
      end

      # Whether any repo profile stable-masks this USE flag — the situation
      # a /etc/portage/profile/use.stable.mask override entry can lift.
      def stable_masked_flag?(flag)
        md5_cache_dirs.any? do |dir|
          Dir.glob(File.join(repo_root(dir), 'profiles', '**', 'use.stable.mask')).any? do |path|
            File.foreach(path).any? { |line| line.strip == flag }
          end
        end
      end

      def portland_stable_unmask_content
        read_if_exists('/etc/portage/profile/use.stable.mask')
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

      # {version:, slot:, keywords:} for every available version of a package,
      # read from each repo's pregenerated metadata cache (SLOT and KEYWORDS
      # already resolved — no ebuild sourcing). Overlays without a
      # metadata/md5-cache directory simply contribute nothing.
      def slot_entries(atom)
        each_cache_file(atom).filter_map do |version, path|
          fields = cache_fields(path, %w[SLOT KEYWORDS])
          next unless fields['SLOT']

          { version: version, slot: fields['SLOT'], keywords: fields.fetch('KEYWORDS', '') }
        end
      end

      # IUSE of the newest cached version (display source for the flag list).
      def package_iuse(atom)
        newest = each_cache_file(atom)
                 .max_by { |version, _| version.scan(/\d+/).map(&:to_i) }
        return '' unless newest

        cache_fields(newest[1], %w[IUSE]).fetch('IUSE', '')
      end

      def each_cache_file(atom)
        category, name = atom.split('/', 2)
        return [] unless category && name

        md5_cache_dirs.flat_map do |dir|
          Dir.glob(File.join(dir, category, "#{name}-*")).filter_map do |path|
            version = File.basename(path).delete_prefix("#{name}-")
            [version, path] if version.match?(/\A\d/)
          end
        end
      end

      def cache_fields(path, names)
        File.foreach(path).each_with_object({}) do |line, fields|
          names.each do |field_name|
            prefix = "#{field_name}="
            fields[field_name] = line.chomp.delete_prefix(prefix) if line.start_with?(prefix)
          end
        end
      end

      def arch
        @arch ||= `portageq envvar ARCH 2>/dev/null`.strip
      end

      def global_use
        @global_use ||= `portageq envvar USE 2>/dev/null`.split.to_set
      rescue Errno::ENOENT
        @global_use = Set.new
      end

      # All entries across every file in a package.* config directory,
      # parsed but unfiltered; domain code decides relevance.
      def use_config_entries
        config_entries('/etc/portage/package.use')
      end

      def keyword_config_entries
        config_entries('/etc/portage/package.accept_keywords')
      end

      def config_entries(dir)
        return [] unless File.directory?(dir)

        Dir.children(dir).sort.flat_map do |file|
          path = File.join(dir, file)
          next [] unless File.file?(path) && File.readable?(path)

          Domain::ConfigFileFormat.parse(File.read(path), file: file)
        end
      end

      def portland_use_content
        read_if_exists('/etc/portage/package.use/zz-portland')
      end

      def portland_keywords_content
        read_if_exists('/etc/portage/package.accept_keywords/zz-portland')
      end

      def read_if_exists(path)
        File.readable?(path) ? File.read(path) : ''
      end

      # {flag => description}: per-package descriptions from use.local.desc
      # overlaid on the global use.desc ones.
      def use_descriptions(atom)
        global_flag_descriptions.merge(local_flag_descriptions.fetch(atom, {}))
      end

      def global_flag_descriptions
        @global_flag_descriptions ||= md5_cache_dirs.each_with_object({}) do |dir, all|
          path = File.join(repo_root(dir), 'profiles', 'use.desc')
          next unless File.readable?(path)

          File.foreach(path) do |line|
            next if line.start_with?('#')

            flag, description = line.chomp.split(' - ', 2)
            all[flag] = description if flag && description
          end
        end
      end

      # The md5-cache dir is <repo>/metadata/md5-cache; profiles sit at the
      # repo root, two levels up.
      def repo_root(md5_cache_dir)
        File.expand_path('../..', md5_cache_dir)
      end

      def local_flag_descriptions
        @local_flag_descriptions ||= md5_cache_dirs.each_with_object({}) do |dir, all|
          path = File.join(repo_root(dir), 'profiles', 'use.local.desc')
          next unless File.readable?(path)

          File.foreach(path) do |line|
            next if line.start_with?('#')

            spec, description = line.chomp.split(' - ', 2)
            next unless spec && description

            atom_key, flag = spec.split(':', 2)
            (all[atom_key] ||= {})[flag] = description if flag
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
