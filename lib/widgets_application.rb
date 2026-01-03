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
    window = create_bar_window
    @windows << window
    window.present
  end

  def on_startup
    Gtk::Settings.default.gtk_application_prefer_dark_theme = true
  end

  def on_shutdown
    @windows.each(&:destroy)
    @windows.clear
  end

  def create_bar_window
    WidgetsWindow.new(application: self)
  end
end
