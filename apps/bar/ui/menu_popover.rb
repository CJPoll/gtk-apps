# frozen_string_literal: true

module Bar
  module UI
    # GTK4 replacement for the Gtk::Menu popups the bar's widgets used:
    # a popover anchored to its trigger widget, holding a vertical list of
    # flat buttons. Items added with a block are actionable and close the
    # popover; items without one are inert headers.
    class MenuPopover < Gtk::Popover
      def initialize(anchor)
        super()
        set_parent(anchor)
        @box = Gtk::Box.new(:vertical, 0)
        @box.add_css_class('bar-menu')
        set_child(@box)

        # A popover parented at popup time must unparent itself once closed
        # or it leaks its anchor widget. Deferred: unparenting during the
        # 'closed' emission itself is unsafe.
        signal_connect('closed') do
          GLib::Idle.add do
            unparent
            false
          end
        end
      end

      def add_header(text)
        label = Gtk::Label.new(text)
        label.halign = :start
        label.add_css_class('bar-menu-header')
        label.sensitive = false
        @box.append(label)
      end

      def add_item(text, sensitive: true, &action)
        label = Gtk::Label.new(text)
        label.halign = :start
        label.hexpand = true

        button = Gtk::Button.new
        button.child = label
        button.has_frame = false
        button.sensitive = sensitive
        button.add_css_class('bar-menu-item')
        button.signal_connect('clicked') do
          popdown
          action&.call
        end
        @box.append(button)
      end

      def add_separator
        @box.append(Gtk::Separator.new(:horizontal))
      end
    end
  end
end
