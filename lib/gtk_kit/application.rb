# frozen_string_literal: true

module GtkKit
  # Application shell shared by every app in the repo: wires the GTK lifecycle
  # signals to overridable hooks and applies the dark theme plus the app's
  # stylesheet stack at startup.
  class Application < Gtk::Application
    def initialize(application_id)
      super(application_id, Gio::ApplicationFlags::FLAGS_NONE)
      signal_connect('activate') { on_activate }
      signal_connect('startup') { base_startup }
      signal_connect('shutdown') { on_shutdown }
    end

    private

    def base_startup
      Gtk::Settings.default.gtk_application_prefer_dark_theme = true
      stylesheet.apply!
      on_startup
    end

    def stylesheet
      @stylesheet ||= Stylesheet.new(stylesheet_paths)
    end

    # Override to layer app CSS over the shared base.
    def stylesheet_paths
      [File.join(GtkKit.root, 'assets', 'base.css')]
    end

    def on_activate; end
    def on_startup; end
    def on_shutdown; end
  end
end
