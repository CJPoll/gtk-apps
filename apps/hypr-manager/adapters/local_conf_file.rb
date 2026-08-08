# frozen_string_literal: true

require 'fileutils'

module HyprManager
  module Adapters
    # Reads and writes ~/hyprland.local.conf (user-owned — no privilege
    # escalation anywhere in this app). The first write of a session copies
    # the previous content aside first.
    module LocalConfFile
      module_function

      PATH = File.expand_path('~/hyprland.local.conf')
      BACKUP = File.join(Dir.home, '.local', 'state', 'hypr-manager',
                         'hyprland.local.conf.bak')

      def read
        File.exist?(PATH) ? File.read(PATH) : ''
      end

      def write(content)
        backup_once
        File.write(PATH, content)
      end

      def backup_once
        return if @backed_up || !File.exist?(PATH)

        FileUtils.mkdir_p(File.dirname(BACKUP))
        FileUtils.cp(PATH, BACKUP)
        @backed_up = true
      end
    end
  end
end
