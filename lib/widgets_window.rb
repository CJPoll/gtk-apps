# frozen_string_literal: true

class WidgetsWindow < Gtk::Window
  BAR_HEIGHT = 32

  def initialize(application:)
    super()
    set_application(application)

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
  end

  def setup_ui
    set_default_size(-1, BAR_HEIGHT)

    @main_box = Gtk::Box.new(:horizontal, 8)
    @main_box.margin_start = 8
    @main_box.margin_end = 8

    setup_left_section
    setup_center_section
    setup_right_section

    add(@main_box)
  end

  def setup_left_section
    @left_box = Gtk::Box.new(:horizontal, 4)

    workspaces_label = Gtk::Label.new('Workspaces')
    @left_box.pack_start(workspaces_label, expand: false, fill: false, padding: 0)

    @main_box.pack_start(@left_box, expand: false, fill: false, padding: 0)
  end

  def setup_center_section
    @center_box = Gtk::Box.new(:horizontal, 4)
    @center_box.halign = :center

    window_title_label = Gtk::Label.new('Window Title')
    @center_box.pack_start(window_title_label, expand: false, fill: false, padding: 0)

    @main_box.pack_start(@center_box, expand: true, fill: true, padding: 0)
  end

  def setup_right_section
    @right_box = Gtk::Box.new(:horizontal, 8)

    clock_label = Gtk::Label.new(Time.now.strftime('%H:%M'))
    @right_box.pack_start(clock_label, expand: false, fill: false, padding: 0)

    # Update clock every second
    GLib::Timeout.add_seconds(1) do
      clock_label.text = Time.now.strftime('%H:%M')
      true # Continue timer
    end

    @main_box.pack_end(@right_box, expand: false, fill: false, padding: 0)
  end

  def setup_signals
    signal_connect('destroy') { on_destroy }
  end

  def on_destroy
    # Cleanup resources if needed
  end
end
