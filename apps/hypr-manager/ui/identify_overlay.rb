# frozen_string_literal: true

module HyprManager
  module UI
    # A large "this is display N" panel centred on one monitor, as a
    # layer-shell OVERLAY surface so it lands on the named output whatever the
    # tiled windows or the manager window are doing. Dismisses itself after the
    # label's display time, or on click.
    class IdentifyOverlay < Gtk::Window
      include GtkKit::Timers

      # Shows an overlay for the label on gdk_monitor. Returns nil (and shows
      # nothing) when layer-shell is unavailable: an ordinary window would open
      # on the wrong screen, and a wrong answer must not look like an identification.
      def self.present_on(label, gdk_monitor)
        return nil unless layer_shell_supported?

        overlay = new(label, gdk_monitor)
        overlay.present
        overlay
      end

      def self.layer_shell_supported?
        defined?(::GtkLayerShell) && ::GtkLayerShell.respond_to?(:supported?) && ::GtkLayerShell.supported?
      end

      def initialize(label, gdk_monitor)
        super()
        add_css_class('identify-overlay')
        set_decorated(false)
        set_resizable(false)
        set_default_size(760, 440)

        pin_to(gdk_monitor)
        set_child(build_panel(label))

        after_ms(Domain::IdentifyLabel::DISPLAY_MS) { close }
      end

      # Idempotent: the timer, a click and the manager may all ask.
      def close
        super unless destroyed?
      end

      private

      # No anchors: layer-shell centres the surface on the output.
      def pin_to(gdk_monitor)
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell::Layer::OVERLAY)
        GtkLayerShell.set_namespace(self, 'hypr-manager-identify')
        GtkLayerShell.set_monitor(self, gdk_monitor)
      end

      def build_panel(label)
        panel = Gtk::Box.new(:vertical, 6)
        panel.add_css_class('identify-panel')
        panel.halign = :fill
        panel.valign = :fill

        panel.append(line(label.number.to_s, 'identify-number', vexpand: true))
        panel.append(line(label.port, 'identify-port'))
        panel.append(line(label.model, 'identify-model'))
        panel.append(line(label.detail, 'identify-detail'))

        click = Gtk::GestureClick.new
        click.signal_connect('pressed') { close }
        panel.add_controller(click)
        panel
      end

      def line(text, css_class, vexpand: false)
        widget = Gtk::Label.new(text)
        widget.add_css_class(css_class)
        widget.vexpand = vexpand
        widget
      end
    end
  end
end
