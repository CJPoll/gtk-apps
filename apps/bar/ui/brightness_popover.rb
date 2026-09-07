# frozen_string_literal: true

module Bar
  module UI
    # A single horizontal slider anchored under the brightness pill. Reports
    # every drag position through `on_change:` so the panel tracks the handle
    # live rather than only on release.
    class BrightnessPopover < Gtk::Popover
      include GtkKit::Timers

      WIDTH = 200

      def initialize(anchor, percent:, on_change:)
        super()
        set_parent(anchor)
        @on_change = on_change

        set_child(build_body(percent))

        # A popover parented at popup time must unparent itself once closed or
        # it leaks its anchor widget. Deferred: unparenting during the 'closed'
        # emission itself is unsafe. on_main_thread (not raw GLib::Idle) so the
        # callback retires instead of firing if the bar is destroyed first —
        # e.g. by the SIGUSR1 visibility toggle.
        signal_connect('closed') do
          on_main_thread { unparent }
        end
      end

      private

      def build_body(percent)
        box = Gtk::Box.new(:horizontal, 8)
        box.add_css_class('brightness-slider')

        @readout = Gtk::Label.new(format('%3d%%', percent))
        @readout.add_css_class('brightness-readout')

        box.append(Gtk::Label.new('󰃝'))
        box.append(build_scale(percent))
        box.append(Gtk::Label.new('󰃠'))
        box.append(@readout)
        box
      end

      def build_scale(percent)
        scale = Gtk::Scale.new(:horizontal)
        scale.set_range(Domain::Brightness::MIN_PERCENT, Domain::Brightness::MAX_PERCENT)
        scale.set_increments(5, 10)
        scale.draw_value = false
        scale.hexpand = true
        scale.set_size_request(WIDTH, -1)

        # Seed before connecting so the initial position is not reported back
        # as a user-made change.
        scale.value = percent
        scale.signal_connect('value-changed') { |widget| handle_change(widget.value.round) }
        scale
      end

      def handle_change(percent)
        @readout.label = format('%3d%%', percent)
        @on_change.call(percent)
      end
    end
  end
end
