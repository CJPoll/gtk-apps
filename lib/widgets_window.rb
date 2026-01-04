# frozen_string_literal: true

class WidgetsWindow < Gtk::Window
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

    show_all
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
    # Get Hyprland's monitor info to find geometry
    hypr_monitors = Compositor::Adapters::HyprlandIpc.monitors
    hypr_monitor = hypr_monitors.find { |m| m['name'] == name }
    return unless hypr_monitor

    hypr_x = hypr_monitor['x']
    hypr_y = hypr_monitor['y']

    # Find GDK monitor with matching geometry position
    display = Gdk::Display.default
    display.n_monitors.times do |i|
      gdk_monitor = display.get_monitor(i)
      geom = gdk_monitor.geometry

      if geom.x == hypr_x && geom.y == hypr_y
        GtkLayerShell.set_monitor(self, gdk_monitor)
        return
      end
    end
  end

  def setup_ui_shell
    set_default_size(-1, BAR_HEIGHT)

    @main_box = Gtk::Box.new(:horizontal, 4)
    @main_box.style_context.add_class('bar-container')

    # Create section containers (lightweight, no widgets yet)
    @left_box = Gtk::Box.new(:horizontal, 4)
    @left_box.style_context.add_class('section-left')
    @left_box.valign = :center

    @center_box = Gtk::Box.new(:horizontal, 4)
    @center_box.style_context.add_class('section-center')
    @center_box.halign = :center
    @center_box.valign = :center

    @right_box = Gtk::Box.new(:horizontal, 4)
    @right_box.style_context.add_class('section-right')
    @right_box.valign = :center

    @main_box.pack_start(@left_box, expand: false, fill: false, padding: 0)
    @main_box.set_center_widget(@center_box)
    @main_box.pack_end(@right_box, expand: false, fill: false, padding: 0)

    add(@main_box)
  end

  def populate_widgets
    # Left section
    add_widget(@left_box, Bar::UI::WorkspacesWidget.new(monitor_name: @monitor_name))

    # Center section
    add_widget(@center_box, Bar::UI::MemoryWidget.new)
    add_widget(@center_box, Bar::UI::CpuWidget.new)
    add_widget(@center_box, Bar::UI::BatteryWidget.new)
    add_widget(@center_box, Bar::UI::BrightnessWidget.new)

    # Right section
    add_widget(@right_box, Bar::UI::AudioSinkWidget.new)
    add_widget(@right_box, Bar::UI::VolumeWidget.new)
    add_widget(@right_box, Bar::UI::NetworkWidget.new)
    add_widget(@right_box, Bar::UI::ClockWidget.new)
    add_widget(@right_box, Bar::UI::TrayWidget.new(sni_host: @sni_host))
    add_widget(@right_box, Bar::UI::PowerControlsWidget.new)
  end

  def add_widget(container, widget)
    container.pack_start(widget, expand: false, fill: false, padding: 0)
    widget.show_all
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
