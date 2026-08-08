# frozen_string_literal: true

module Bar
  module UI
    class LaunchersWidget < Gtk::Box
      # Desktop file names (without .desktop extension)
      LAUNCHER_APPS = %w[
        discord
        spotify
        slack
        steam
        pyrope
        beryl
      ].freeze

      def initialize
        super(:horizontal, 0)

        add_css_class('pill')
        add_css_class('launchers')

        setup_ui
      end

      private

      def setup_ui
        LAUNCHER_APPS.each do |app_name|
          launcher = Bar::Domain::Launcher.from_desktop_file(app_name)
          next unless launcher

          button = LauncherButton.new(launcher: launcher)
          append(button)
        end
      end
    end
  end
end
