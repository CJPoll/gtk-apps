# frozen_string_literal: true

module HyprManager
  class Application < GtkKit::Application
    def initialize
      super('com.example.HyprManager')
      @window = nil
    end

    private

    def stylesheet_paths
      super + [File.join(__dir__, 'assets', 'hypr-manager.css')]
    end

    # Re-activation (a second launch forwarded to this instance) presents
    # the existing window rather than stacking a new one.
    def on_activate
      @window = Window.new(application: self) if @window.nil? || @window.destroyed?
      @window.present
    end

    def on_shutdown
      @window&.destroy
    end
  end
end
