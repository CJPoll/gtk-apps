# frozen_string_literal: true

module Portland
  class Application < GtkKit::Application
    def initialize
      super('com.example.portland')
      @window = nil
    end

    private

    def stylesheet_paths
      super + [File.join(__dir__, 'assets', 'portland.css')]
    end

    # Launching portland while an instance is running forwards the second
    # launch here as another 'activate'; present the existing window rather
    # than stacking a new one per launch.
    def on_activate
      @window = Window.new(application: self) if @window.nil? || @window.destroyed?
      @window.present
    end

    def on_shutdown
      @window&.destroy
    end
  end
end
