# frozen_string_literal: true

module GtkKit
  # Applies a stack of CSS files to the default screen, in order, so an app's
  # own sheet layers over the shared base. Reloadable in place for live
  # style iteration.
  class Stylesheet
    def initialize(paths)
      @paths = paths
      @providers = {}
    end

    def apply!
      @paths.each do |path|
        unless File.exist?(path)
          warn "Stylesheet not found: #{path}"
          next
        end

        provider = Gtk::CssProvider.new
        provider.load(path: path)
        Gtk::StyleContext.add_provider_for_screen(
          Gdk::Screen.default,
          provider,
          Gtk::StyleProvider::PRIORITY_USER
        )
        @providers[path] = provider
      end
    end

    def reload!
      @providers.each do |path, provider|
        provider.load(path: path) if File.exist?(path)
      end
    end
  end
end
