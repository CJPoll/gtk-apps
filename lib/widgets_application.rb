# frozen_string_literal: true

class WidgetsApplication < Gtk::Application
  def initialize
    super('com.example.widgets', Gio::ApplicationFlags::FLAGS_NONE)
    @windows = []
    setup_signals
  end

  private

  def setup_signals
    signal_connect('activate') { on_activate }
    signal_connect('startup') { on_startup }
    signal_connect('shutdown') { on_shutdown }
  end

  def on_activate
    # Create one bar per monitor
    monitors = Compositor::Adapters::HyprlandIpc.monitors
    monitors.each do |monitor|
      window = create_bar_window(monitor['name'])
      @windows << window
      window.present
    end
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
    else
      warn "CSS file not found: #{css_path}"
    end
  end

  def on_shutdown
    @windows.each(&:destroy)
    @windows.clear
  end

  def create_bar_window(monitor_name)
    WidgetsWindow.new(application: self, monitor_name: monitor_name)
  end
end
