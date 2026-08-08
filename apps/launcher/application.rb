# frozen_string_literal: true

module Launcher
  class Application < GtkKit::Application
    def initialize
      super('com.example.launcher')
      @window = nil
      @dock_visible = true
      setup_unix_signals
    end

    private

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
      @window.visible = @dock_visible
    end

    def stylesheet_paths
      super + [File.join(__dir__, 'assets', 'launcher.css')]
    end

    # Re-activation (a second launch forwarded to this instance) presents
    # the existing dock — and un-hides it, so a stray relaunch can't leave
    # the visibility flag out of sync.
    def on_activate
      @window = Window.new(application: self) if @window.nil? || @window.destroyed?
      @dock_visible = true
      @window.present
    end

    def on_shutdown
      @window&.destroy
    end
  end
end
