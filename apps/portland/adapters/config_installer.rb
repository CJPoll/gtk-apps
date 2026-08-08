# frozen_string_literal: true

require 'fileutils'

module Portland
  module Adapters
    # Installs portland's staged config files into /etc/portage. Runs
    # headless via sudo -A — the askpass dialog collects the password, no
    # terminal needed — and reports success back on the main loop.
    module ConfigInstaller
      module_function

      STAGING_DIR = File.join(Dir.home, '.local', 'state', 'portland')
      TARGETS = {
        'package.use' => '/etc/portage/package.use/zz-portland',
        'package.accept_keywords' => '/etc/portage/package.accept_keywords/zz-portland',
        'use.stable.mask' => '/etc/portage/profile/use.stable.mask'
      }.freeze

      def install(use_content, keywords_content, stable_unmask_content: nil, &on_done)
        FileUtils.mkdir_p(STAGING_DIR)
        contents = {
          'package.use' => use_content,
          'package.accept_keywords' => keywords_content
        }
        contents['use.stable.mask'] = stable_unmask_content if stable_unmask_content

        staged = contents.to_h do |name, content|
          path = File.join(STAGING_DIR, name)
          File.write(path, content)
          [path, TARGETS.fetch(name)]
        end

        # -D creates /etc/portage/profile on first use
        installs = staged.map { |src, dest| "install -D -m 0644 #{src} #{dest}" }.join(' && ')

        Thread.new do
          success = system({ 'SUDO_ASKPASS' => Terminal.askpass_path },
                           'sudo', '-A', 'sh', '-c', installs)

          GLib::Idle.add do
            on_done.call(!!success)
            false
          end
        end
      end
    end
  end
end
