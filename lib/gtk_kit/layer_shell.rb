# frozen_string_literal: true

module GtkKit
  # Loads the gtk4-layer-shell typelib via GObject Introspection, defining the
  # top-level ::GtkLayerShell module. Opt-in: bar and launcher are layer-shell
  # clients, but a fullscreen app (the greeter) never calls this.
  #
  # The GIR namespace is Gtk4LayerShell, but it is exposed here under the
  # ::GtkLayerShell name so call sites stay toolkit-version-agnostic — the
  # function and enum surface (init_for_window, Layer, Edge) is identical.
  module LayerShell
    def self.load!
      return if defined?(::GtkLayerShell)

      require 'gobject-introspection'

      shell = Object.const_set(:GtkLayerShell, Module.new)
      loader = GObjectIntrospection::Loader.new(shell)
      loader.load('Gtk4LayerShell')
    end
  end
end
