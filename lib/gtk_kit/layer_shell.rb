# frozen_string_literal: true

module GtkKit
  # Loads the gtk-layer-shell typelib via GObject Introspection, defining the
  # top-level ::GtkLayerShell module. Opt-in: bar and launcher are layer-shell
  # clients, but a fullscreen app (the greeter) never calls this.
  module LayerShell
    def self.load!
      return if defined?(::GtkLayerShell)

      require 'gobject-introspection'

      shell = Object.const_set(:GtkLayerShell, Module.new)
      loader = GObjectIntrospection::Loader.new(shell)
      loader.load('GtkLayerShell')
    end
  end
end
