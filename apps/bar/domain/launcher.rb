# frozen_string_literal: true

module Bar
  module Domain
    class Launcher
      DESKTOP_DIRS = [
        '/usr/share/applications',
        File.expand_path('~/.local/share/applications')
      ].freeze

      attr_reader :name, :icon_name, :desktop_file

      def initialize(name:, icon_name:, desktop_file:)
        @name = name
        @icon_name = icon_name
        @desktop_file = desktop_file
      end

      def launch
        pid = spawn('gio', 'launch', @desktop_file, pgroup: true, [:out, :err] => '/dev/null')
        Process.detach(pid)
      end

      class << self
        def from_desktop_file(filename)
          path = find_desktop_file(filename)
          return nil unless path

          parse_desktop_file(path)
        end

        private

        def find_desktop_file(filename)
          filename = "#{filename}.desktop" unless filename.end_with?('.desktop')

          DESKTOP_DIRS.each do |dir|
            path = File.join(dir, filename)
            return path if File.exist?(path)
          end

          nil
        end

        def parse_desktop_file(path)
          name = nil
          icon = nil

          File.readlines(path).each do |line|
            line = line.strip
            if line.start_with?('Name=') && name.nil?
              name = line.sub('Name=', '')
            elsif line.start_with?('Icon=')
              icon = line.sub('Icon=', '')
            end

            break if name && icon
          end

          return nil unless name && icon

          new(name: name, icon_name: icon, desktop_file: path)
        end
      end
    end
  end
end
