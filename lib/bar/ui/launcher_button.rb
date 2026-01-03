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
        style_context.add_class('launcher')

        icon = create_icon
        set_image(icon)
        set_always_show_image(true)
        set_relief(:none)

        set_tooltip_text(@launcher.name)
      end

      def create_icon
        icon_theme = Gtk::IconTheme.default

        pixbuf = if icon_theme.has_icon?(@launcher.icon_name)
                   icon_theme.load_icon(@launcher.icon_name, ICON_SIZE, :force_size)
                 elsif File.exist?(@launcher.icon_name)
                   GdkPixbuf::Pixbuf.new(file: @launcher.icon_name, width: ICON_SIZE, height: ICON_SIZE)
                 else
                   icon_theme.load_icon('application-x-executable', ICON_SIZE, :force_size)
                 end

        Gtk::Image.new(pixbuf: pixbuf)
      end

      def setup_signals
        signal_connect('clicked') { @launcher.launch }
      end
    end
  end
end
