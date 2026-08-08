# frozen_string_literal: true

module Portland
  module UI
    # One search result. The header shows atom, description, installed badge,
    # and a toggle marking the bare atom (portage picks the default slot).
    # Expanding the row lists the package's slots, each markable individually
    # as "category/name:slot".
    class PackageRow < Gtk::ListBoxRow
      attr_reader :package

      def initialize(package, slot_fetcher:, marked_lookup:, on_toggle:)
        super()
        @package = package
        @slot_fetcher = slot_fetcher
        @marked_lookup = marked_lookup
        @on_toggle = on_toggle
        @updating = false
        @toggles = {}
        @slots_requested = false

        build
      end

      # Untoggles everything without notifying, for when the plan is cleared.
      def reset!
        @updating = true
        @toggles.each_value { |toggle| toggle.active = false }
        @updating = false
      end

      private

      def build
        @expander = Gtk::Expander.new
        @expander.label_fill = true
        @expander.label_widget = build_header
        @expander.signal_connect('notify::expanded') do
          load_slots if @expander.expanded?
        end

        @slot_box = Gtk::Box.new(:vertical, 4)
        @slot_box.style_context.add_class('slot-list')
        @expander.add(@slot_box)

        add(@expander)
      end

      def build_header
        box = Gtk::Box.new(:horizontal, 12)
        box.style_context.add_class('package-row')

        box.pack_start(build_text, expand: true, fill: true, padding: 0)
        box.pack_start(build_badge, expand: false, fill: false, padding: 0) if @package.installed
        box.pack_end(build_toggle(atom: @package.atom, installed: @package.installed),
                     expand: false, fill: false, padding: 0)
        box
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

      def build_toggle(atom:, installed:)
        toggle = Gtk::ToggleButton.new(label: installed ? 'Remove' : 'Install')
        toggle.valign = :center
        toggle.active = !@marked_lookup.call(atom).nil?
        toggle.style_context.add_class(installed ? 'mark-remove' : 'mark-install')
        toggle.signal_connect('toggled') { notify_toggle(atom, installed) }
        @toggles[atom] = toggle
        toggle
      end

      def notify_toggle(atom, installed)
        return if @updating

        @on_toggle.call(atom, installed ? :remove : :install)
      end

      def load_slots
        return if @slots_requested

        @slots_requested = true
        loading = Gtk::Label.new('Loading slots…')
        loading.style_context.add_class('slot-note')
        @slot_box.add(loading)
        @slot_box.show_all

        @slot_fetcher.fetch(@package.atom) do |options|
          loading.destroy
          render_slots(options)
        end
      end

      def render_slots(options)
        if options.empty?
          note = Gtk::Label.new('No slot metadata available for this package')
          note.style_context.add_class('slot-note')
          @slot_box.add(note)
        else
          options.each { |option| @slot_box.add(build_slot_row(option)) }
        end

        @slot_box.show_all
      end

      def build_slot_row(option)
        row = Gtk::Box.new(:horizontal, 12)
        row.style_context.add_class('slot-row')

        label = Gtk::Label.new("slot #{option.slot} — #{option.newest_version}")
        label.halign = :start
        row.pack_start(label, expand: true, fill: true, padding: 0)

        row.pack_start(build_badge, expand: false, fill: false, padding: 0) if option.installed
        row.pack_end(build_toggle(atom: "#{@package.atom}:#{option.slot}", installed: option.installed),
                     expand: false, fill: false, padding: 0)
        row
      end
    end
  end
end
