# frozen_string_literal: true

class WidgetsWindow < Gtk::Window
  BAR_HEIGHT = 48

  attr_reader :monitor_name

  def initialize(application:, monitor_name:)
    super()
    set_application(application)
    @monitor_name = monitor_name

    setup_layer_shell
    setup_ui
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

  def setup_ui
    set_default_size(-1, BAR_HEIGHT)

    @main_box = Gtk::Box.new(:horizontal, 4)
    @main_box.style_context.add_class('bar-container')

    setup_left_section
    setup_center_section
    setup_right_section

    add(@main_box)
  end

  def setup_left_section
    @left_box = Gtk::Box.new(:horizontal, 4)
    @left_box.style_context.add_class('section-left')

    # Workspaces widget (filtered by this monitor)
    @workspaces = Bar::UI::WorkspacesWidget.new(monitor_name: @monitor_name)
    @left_box.pack_start(@workspaces, expand: false, fill: false, padding: 0)

    # App launchers
    @launchers = Bar::UI::LaunchersWidget.new
    @left_box.pack_start(@launchers, expand: false, fill: false, padding: 0)

    @main_box.pack_start(@left_box, expand: false, fill: false, padding: 0)
  end

  def setup_center_section
    @center_box = Gtk::Box.new(:horizontal, 4)
    @center_box.style_context.add_class('section-center')
    @center_box.halign = :center

    # Memory widget
    @memory = Bar::UI::MemoryWidget.new
    @center_box.pack_start(@memory, expand: false, fill: false, padding: 0)

    # CPU widget
    @cpu = Bar::UI::CpuWidget.new
    @center_box.pack_start(@cpu, expand: false, fill: false, padding: 0)

    # Battery widget (auto-hides on desktop)
    @battery = Bar::UI::BatteryWidget.new
    @center_box.pack_start(@battery, expand: false, fill: false, padding: 0)

    # Brightness widget (auto-hides on desktop)
    @brightness = Bar::UI::BrightnessWidget.new
    @center_box.pack_start(@brightness, expand: false, fill: false, padding: 0)

    # Center the box by expanding but not filling
    @main_box.set_center_widget(@center_box)
  end

  def setup_right_section
    @right_box = Gtk::Box.new(:horizontal, 4)
    @right_box.style_context.add_class('section-right')

    # Volume widget
    @volume = Bar::UI::VolumeWidget.new
    @right_box.pack_start(@volume, expand: false, fill: false, padding: 0)

    # Audio sink widget
    @audio_sink = Bar::UI::AudioSinkWidget.new
    @right_box.pack_start(@audio_sink, expand: false, fill: false, padding: 0)

    # Clock widget
    @clock = Bar::UI::ClockWidget.new
    @right_box.pack_start(@clock, expand: false, fill: false, padding: 0)

    # Power controls
    @power_controls = Bar::UI::PowerControlsWidget.new
    @right_box.pack_start(@power_controls, expand: false, fill: false, padding: 0)

    @main_box.pack_end(@right_box, expand: false, fill: false, padding: 0)
  end

  def setup_signals
    signal_connect('destroy') { on_destroy }
  end

  def on_destroy
    # Cleanup resources if needed
  end
end
