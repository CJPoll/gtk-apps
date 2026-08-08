# frozen_string_literal: true

module Portland
  module UI
    # One search result: atom, description, installed badge, and a toggle
    # marking the package for install (not installed) or removal (installed).
    class PackageRow < Gtk::ListBoxRow
      attr_reader :package

      def initialize(package, marked:, on_toggle:)
        super()
        @package = package
        @on_toggle = on_toggle
        @updating = false

        build(marked)
      end

      # Untoggles without notifying, for when the plan is cleared wholesale.
      def reset!
        @updating = true
        @toggle.active = false
        @updating = false
      end

      private

      def build(marked)
        box = Gtk::Box.new(:horizontal, 12)
        box.style_context.add_class('package-row')

        box.pack_start(build_text, expand: true, fill: true, padding: 0)
        box.pack_start(build_badge, expand: false, fill: false, padding: 0) if @package.installed
        box.pack_end(build_toggle(marked), expand: false, fill: false, padding: 0)

        add(box)
      end

      def build_text
        text = Gtk::Box.new(:vertical, 2)

        name = Gtk::Label.new(@package.atom)
        name.halign = :start
        name.style_context.add_class('package-name')

        description = Gtk::Label.new(@package.description)
        description.halign = :start
        description.ellipsize = :end
        description.style_context.add_class('package-description')

        text.pack_start(name, expand: false, fill: false, padding: 0)
        text.pack_start(description, expand: false, fill: false, padding: 0)
        text
      end

      def build_badge
        badge = Gtk::Label.new('installed')
        badge.valign = :center
        badge.style_context.add_class('installed-badge')
        badge
      end

      def build_toggle(marked)
        @toggle = Gtk::ToggleButton.new(label: @package.installed ? 'Remove' : 'Install')
        @toggle.valign = :center
        @toggle.active = marked
        @toggle.style_context.add_class(@package.installed ? 'mark-remove' : 'mark-install')
        @toggle.signal_connect('toggled') { notify_toggle }
        @toggle
      end

      def action
        @package.installed ? :remove : :install
      end

      def notify_toggle
        return if @updating

        @on_toggle.call(@package, action)
      end
    end
  end
end
