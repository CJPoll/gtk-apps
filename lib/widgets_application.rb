# frozen_string_literal: true

class WidgetsApplication < Gtk::Application
  def initialize
    super('com.example.widgets', Gio::ApplicationFlags::FLAGS_NONE)
    @windows = []
    @sni_host = nil
    @css_provider = nil
    @bars_visible = true
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
    # SIGUSR1: Toggle bar visibility
    Signal.trap('USR1') do
      GLib::Idle.add do
        toggle_visibility
        false
      end
    end

    # SIGUSR2: Reload CSS styles
    Signal.trap('USR2') do
      GLib::Idle.add do
        reload_css
        false
      end
    end
  end

  def toggle_visibility
    @bars_visible = !@bars_visible
    @windows.each do |window|
      if @bars_visible
        window.show
      else
        window.hide
      end
    end
  end

  def reload_css
    return unless @css_provider

    css_path = File.join(File.dirname(__FILE__), '..', 'assets', 'style.css')
    return unless File.exist?(css_path)

    @css_provider.load(path: css_path)
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
    start_sni_host
  end

  def start_sni_host
    @sni_host = Bar::Adapters::SniHost.new
    @sni_host.start
    @sni_host.register_self_as_host
  rescue StandardError => e
    warn "Failed to start SNI host: #{e.message}"
  end

  def load_css
    @css_provider = Gtk::CssProvider.new
    css_path = File.join(File.dirname(__FILE__), '..', 'assets', 'style.css')

    if File.exist?(css_path)
      @css_provider.load(path: css_path)
      Gtk::StyleContext.add_provider_for_screen(
        Gdk::Screen.default,
        @css_provider,
        Gtk::StyleProvider::PRIORITY_USER
      )
    else
      warn "CSS file not found: #{css_path}"
    end
  end

  def on_shutdown
    @sni_host&.stop
    @windows.each(&:destroy)
    @windows.clear
  end

  def create_bar_window(monitor_name)
    WidgetsWindow.new(application: self, monitor_name: monitor_name, sni_host: @sni_host)
  end
end
