# frozen_string_literal: true

class LauncherApplication < Gtk::Application
  def initialize
    super('com.example.launcher', Gio::ApplicationFlags::FLAGS_NONE)
    @window = nil
    @dock_visible = true
    setup_signals
    setup_unix_signals
  end

  private

  def setup_signals
    signal_connect('activate') { on_activate }
    signal_connect('startup') { on_startup }
    signal_connect('shutdown') { on_shutdown }
  end

  def setup_unix_signals
    # SIGUSR1: Toggle dock visibility
    Signal.trap('USR1') do
      GLib::Idle.add do
        toggle_visibility
        false
      end
    end
  end

  def toggle_visibility
    return unless @window && !@window.destroyed?

    @dock_visible = !@dock_visible
    @dock_visible ? @window.show : @window.hide
  end

  def on_activate
    @window = LauncherWindow.new(application: self)
    @window.present
  end

  def on_startup
    Gtk::Settings.default.gtk_application_prefer_dark_theme = true
    load_css
  end

  def load_css
    provider = Gtk::CssProvider.new
    css_path = File.join(File.dirname(__FILE__), '..', 'assets', 'style.css')

    if File.exist?(css_path)
      provider.load(path: css_path)
      Gtk::StyleContext.add_provider_for_screen(
        Gdk::Screen.default,
        provider,
        Gtk::StyleProvider::PRIORITY_USER
      )
    end
  end

  def on_shutdown
    @window&.destroy
  end
end
