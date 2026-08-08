# frozen_string_literal: true

module Bar
  class Application < GtkKit::Application
    # Hyprland launches exec-once clients while its backend is still coming up,
    # so the monitor list can be empty (or the IPC socket unanswerable) for the
    # first moments of a session. Wait for it rather than starting with no bars.
    MONITOR_WAIT_ATTEMPTS = 50
    MONITOR_WAIT_INTERVAL_SECONDS = 0.1

    # A hotplugged monitor reaches GDK a little after Hyprland announces it.
    MONITOR_SETTLE_ATTEMPTS = 20
    MONITOR_SETTLE_INTERVAL_MS = 100

    def initialize
      super('com.example.widgets')
      @windows = []
      @sni_host = nil
      @bars_visible = true
      @events = nil
      setup_unix_signals
    end

    private

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
          stylesheet.reload!
          false
        end
      end
    end

    def toggle_visibility
      @bars_visible = !@bars_visible
      @windows.each { |window| window.visible = @bars_visible }
    end

    def stylesheet_paths
      super + [File.join(__dir__, 'assets', 'bar.css')]
    end

    def on_activate
      monitors = await_monitors

      if monitors.empty?
        warn "No monitors reported by Hyprland after #{monitor_wait_seconds}s; starting no bars."
        return
      end

      # Create one bar per monitor
      monitors.each { |monitor| add_bar(monitor['name']) }

      # Bars come and go with monitors; without this the application would quit
      # the moment the last monitor is unplugged and never come back.
      hold
      watch_monitor_changes
    end

    def await_monitors
      MONITOR_WAIT_ATTEMPTS.times do
        monitors = Compositor::Adapters::HyprlandIpc.monitors
        return monitors unless monitors.empty?

        sleep(MONITOR_WAIT_INTERVAL_SECONDS)
      end

      []
    end

    def monitor_wait_seconds
      (MONITOR_WAIT_ATTEMPTS * MONITOR_WAIT_INTERVAL_SECONDS).round(1)
    end

    def watch_monitor_changes
      @events = Compositor::Adapters::HyprlandEvents.new
      @events.on('monitoradded') { |monitor_name| add_bar_when_ready(monitor_name) }
      @events.on('monitorremoved') { |monitor_name| remove_bar(monitor_name) }
      @events.start
    end

    def add_bar_when_ready(monitor_name, attempts_left = MONITOR_SETTLE_ATTEMPTS)
      if Compositor::Adapters::GdkMonitors.find_by_name(monitor_name)
        add_bar(monitor_name)
        return
      end

      unless attempts_left.positive?
        warn "GDK never reported monitor #{monitor_name}; adding its bar unplaced."
        add_bar(monitor_name)
        return
      end

      GLib::Timeout.add(MONITOR_SETTLE_INTERVAL_MS) do
        add_bar_when_ready(monitor_name, attempts_left - 1)
        false
      end
    end

    def add_bar(monitor_name)
      return if bar_for(monitor_name)

      window = create_bar_window(monitor_name)
      @windows << window
      forget_bar_on_destroy(window)
      window.present
    end

    # GTK tears a bar down on its own when the output beneath it disappears,
    # without ever going through remove_bar. Drop our reference at that moment,
    # or a replugged monitor looks like one that already has a bar and never
    # gets a new one.
    def forget_bar_on_destroy(window)
      window.signal_connect('destroy') { @windows.delete(window) }
    end

    def remove_bar(monitor_name)
      window = bar_for(monitor_name)
      return unless window

      @windows.delete(window)
      # Losing the output races with this event and may have destroyed the
      # window already; GTK raises TypeError on a second destroy.
      window.destroy unless window.destroyed?
    end

    def bar_for(monitor_name)
      @windows.find do |window|
        !window.destroyed? && window.monitor_name == monitor_name
      end
    end

    def on_startup
      start_sni_host
    end

    def start_sni_host
      @sni_host = Adapters::SniHost.new
      @sni_host.start
      @sni_host.register_self_as_host
    rescue StandardError => e
      warn "Failed to start SNI host: #{e.message}"
    end

    def on_shutdown
      @events&.stop
      @sni_host&.stop
      # Destroying a bar prunes it from @windows, so iterate over a copy.
      @windows.dup.each { |window| window.destroy unless window.destroyed? }
      @windows.clear
    end

    def create_bar_window(monitor_name)
      Window.new(application: self, monitor_name: monitor_name, sni_host: @sni_host)
    end
  end
end
