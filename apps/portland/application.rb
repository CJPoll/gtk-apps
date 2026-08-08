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

    def on_activate
      @window = Window.new(application: self)
      @window.present
    end

    def on_shutdown
      @window&.destroy
    end
  end
end
