# frozen_string_literal: true

module Launcher
  class Window < Gtk::Window
    def initialize(application:)
      super()
      set_application(application)

      setup_layer_shell
      setup_ui
    end

    private

    def setup_layer_shell
      GtkLayerShell.init_for_window(self)

      # Place on top layer (above normal windows)
      GtkLayerShell.set_layer(self, GtkLayerShell::Layer::TOP)

      # Anchor to bottom edge, centered horizontally
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::BOTTOM, true)
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::LEFT, false)
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::RIGHT, false)
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::TOP, false)

      # Reserve space at bottom for dock
      GtkLayerShell.set_exclusive_zone(self, 76)

      # No margin - dock CSS handles visual spacing
      GtkLayerShell.set_margin(self, GtkLayerShell::Edge::BOTTOM, 0)
    end

    def setup_ui
      @dock = UI::Dock.new
      set_child(@dock)
    end
  end
end
