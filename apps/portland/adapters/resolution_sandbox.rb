# frozen_string_literal: true

require 'fileutils'

module Portland
  module Adapters
    # Builds a throwaway copy of /etc/portage with portland's staged config
    # applied, for PORTAGE_CONFIGROOT resolution runs. This is how staged
    # changes participate in dependency resolution before anything is
    # installed to the real /etc/portage.
    module ResolutionSandbox
      module_function

      DIR = File.join(Dir.home, '.local', 'state', 'portland', 'sandbox')

      def build(use_content:, keywords_content:, stable_unmask_content:)
        etc = File.join(DIR, 'etc')
        FileUtils.rm_rf(DIR)
        FileUtils.mkdir_p(etc)

        # cp -a rather than FileUtils.cp_r: the latter follows symlinks, and
        # make.profile links into the repo tree. Unreadable root-only files
        # are skipped, which is fine for resolution purposes.
        system('cp', '-a', '/etc/portage', File.join(etc, 'portage'), err: File::NULL)
        repoint_profile_link(File.join(etc, 'portage', 'make.profile'))

        write(File.join(etc, 'portage', 'package.use', 'zz-portland'), use_content)
        write(File.join(etc, 'portage', 'package.accept_keywords', 'zz-portland'), keywords_content)
        write(File.join(etc, 'portage', 'profile', 'use.stable.mask'), stable_unmask_content)

        DIR
      end

      # The copied symlink is often repo-relative and dangles inside the
      # sandbox; portage then declares the whole profile invalid.
      def repoint_profile_link(link)
        target = File.realpath('/etc/portage/make.profile')
        FileUtils.rm_f(link)
        File.symlink(target, link)
      rescue Errno::ENOENT
        nil
      end

      def write(path, content)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end
    end
  end
end
