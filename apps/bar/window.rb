# frozen_string_literal: true

module Bar
  class Window < Gtk::Window
    BAR_HEIGHT = 40

    attr_reader :monitor_name

    def initialize(application:, monitor_name:, sni_host: nil)
      super()
      set_application(application)
      @monitor_name = monitor_name
      @sni_host = sni_host
      @widgets_populated = false

      setup_layer_shell
      setup_ui_shell
      setup_signals
    end

    private

    def setup_layer_shell
      GtkLayerShell.init_for_window(self)

      # Place on top layer (above normal windows, below fullscreen)
      GtkLayerShell.set_layer(self, GtkLayerShell::Layer::TOP)

      # Anchor to top edge, stretch horizontally
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::TOP, true)
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::LEFT, true)
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::RIGHT, true)
      GtkLayerShell.set_anchor(self, GtkLayerShell::Edge::BOTTOM, false)

      # Reserve exclusive zone so windows don't overlap the bar
      GtkLayerShell.set_exclusive_zone(self, BAR_HEIGHT)

      # No margins
      GtkLayerShell.set_margin(self, GtkLayerShell::Edge::TOP, 0)
      GtkLayerShell.set_margin(self, GtkLayerShell::Edge::LEFT, 0)
      GtkLayerShell.set_margin(self, GtkLayerShell::Edge::RIGHT, 0)

      # Set monitor for this bar
      set_monitor_by_name(@monitor_name)
    end

    def set_monitor_by_name(name)
      gdk_monitor = Compositor::Adapters::GdkMonitors.find_by_name(name)
      return unless gdk_monitor

      GtkLayerShell.set_monitor(self, gdk_monitor)
    end

    def setup_ui_shell
      set_default_size(-1, BAR_HEIGHT)

      # GTK4 Box has no center widget; CenterBox is the dedicated container.
      @main_box = Gtk::CenterBox.new
      @main_box.add_css_class('bar-container')

      # Create section containers (lightweight, no widgets yet)
      @left_box = Gtk::Box.new(:horizontal, 4)
      @left_box.add_css_class('section-left')
      @left_box.valign = :center

      @center_box = Gtk::Box.new(:horizontal, 4)
      @center_box.add_css_class('section-center')
      @center_box.halign = :center
      @center_box.valign = :center

      @right_box = Gtk::Box.new(:horizontal, 4)
      @right_box.add_css_class('section-right')
      @right_box.valign = :center

      @main_box.start_widget = @left_box
      @main_box.center_widget = @center_box
      @main_box.end_widget = @right_box

      set_child(@main_box)
    end

    def populate_widgets
      # Left section
      add_widget(@left_box, UI::WorkspacesWidget.new(monitor_name: @monitor_name))
      add_widget(@left_box, UI::VolumeWidget.new)
      add_widget(@left_box, UI::AudioSinkWidget.new)

      # Center section
      add_widget(@center_box, UI::MemoryWidget.new)
      add_widget(@center_box, UI::CpuWidget.new)
      add_widget(@center_box, UI::BatteryWidget.new)
      add_widget(@center_box, UI::BrightnessWidget.new)

      # Right section
      add_widget(@right_box, UI::NetworkWidget.new)
      add_widget(@right_box, UI::ClockWidget.new)
      add_widget(@right_box, UI::TrayWidget.new(sni_host: @sni_host))
      add_widget(@right_box, UI::PowerControlsWidget.new)
    end

    def add_widget(container, widget)
      container.append(widget)
    end

    def setup_signals
      signal_connect('destroy') { on_destroy }
      signal_connect('map') { on_map }
    end

    def on_map
      return if @widgets_populated

      @widgets_populated = true
      populate_widgets
    end

    def on_destroy
      # Cleanup resources if needed
    end
  end
end
