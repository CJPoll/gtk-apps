# frozen_string_literal: true

module GtkKit
  # GLib timers and idle callbacks live on the application's main loop, not on
  # the widget that scheduled them. When a monitor is unplugged GTK destroys
  # that monitor's bar and every widget inside it, but the callbacks keep
  # firing: the next tick touches a destroyed GLib::Object, and the resulting
  # TypeError escapes Gio::Application#run and takes down every other bar with
  # it. Scheduling through these helpers ties a callback's life to its widget's.
  module Timers
    # Repeating timer. Retires itself once the widget is destroyed.
    def every_seconds(interval, &block)
      GLib::Timeout.add_seconds(interval) { tick(repeat: true, &block) }
    end

    # Repeating timer on a sub-second interval.
    def every_ms(interval, &block)
      GLib::Timeout.add(interval) { tick(repeat: true, &block) }
    end

    # One-shot timer. Skipped if the widget is gone by the time it fires.
    def after_ms(delay, &block)
      GLib::Timeout.add(delay) { tick(repeat: false, &block) }
    end

    # Hop back to the main loop from a worker thread or a D-Bus callback.
    # Skipped if the widget is gone by the time it runs.
    def on_main_thread(&block)
      GLib::Idle.add { tick(repeat: false, &block) }
    end

    private

    # A GLib callback that returns false unregisters its source, so a destroyed
    # widget's timers drop off the main loop on their next tick.
    def tick(repeat:)
      return false if destroyed?

      yield
      repeat
    end
  end
end
