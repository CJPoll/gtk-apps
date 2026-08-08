# frozen_string_literal: true

module Bar
  module UI
    class LauncherButton < Gtk::Button
      ICON_SIZE = 18

      def initialize(launcher:)
        super()

        @launcher = launcher

        setup_ui
        setup_signals
      end

      private

      def setup_ui
        add_css_class('launcher')

        set_child(create_icon)
        self.has_frame = false

        set_tooltip_text(@launcher.name)
      end

      def create_icon
        image = Gtk::Image.new
        image.pixel_size = ICON_SIZE

        icon_theme = Gtk::IconTheme.get_for_display(Gdk::Display.default)
        if icon_theme.has_icon?(@launcher.icon_name)
          image.set_from_icon_name(@launcher.icon_name)
        elsif File.exist?(@launcher.icon_name)
          image.set_from_file(@launcher.icon_name)
        else
          image.set_from_icon_name('application-x-executable')
        end

        image
      end

      def setup_signals
        signal_connect('clicked') { @launcher.launch }
      end
    end
  end
end
