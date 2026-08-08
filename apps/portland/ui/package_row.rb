# frozen_string_literal: true

module Portland
  module UI
    # One search result. The header shows atom, description, installed badge,
    # and a toggle marking the bare atom (portage resolves the default slot).
    # Expanding the row reveals the package's detail panel: slots (markable
    # individually as "category/name:slot", with keyword acceptance for
    # testing-only slots) and USE flag checkboxes backed by
    # /etc/portage/package.use.
    class PackageRow < Gtk::ListBoxRow
      attr_reader :package

      def initialize(package, detail_fetcher:, marked_lookup:, use_staged_lookup:,
                     keyword_staged_lookup:, on_toggle:, on_use_toggle:, on_keyword_toggle:)
        super()
        @package = package
        @detail_fetcher = detail_fetcher
        @marked_lookup = marked_lookup
        @use_staged_lookup = use_staged_lookup
        @keyword_staged_lookup = keyword_staged_lookup
        @on_toggle = on_toggle
        @on_use_toggle = on_use_toggle
        @on_keyword_toggle = on_keyword_toggle
        @updating = false
        @details_requested = false

        build
      end

      private

      def build
        @expander = Gtk::Expander.new
        @expander.label_fill = true
        @expander.label_widget = build_header
        @expander.signal_connect('notify::expanded') do
          load_details if @expander.expanded?
        end

        @detail_box = Gtk::Box.new(:vertical, 4)
        @detail_box.style_context.add_class('slot-list')
        @expander.add(@detail_box)

        add(@expander)
      end

      def build_header
        box = Gtk::Box.new(:horizontal, 12)
        box.style_context.add_class('package-row')

        box.pack_start(build_text, expand: true, fill: true, padding: 0)
        box.pack_start(badge('installed', 'installed-badge'), expand: false, fill: false, padding: 0) if @package.installed
        header_action = @package.installed ? :remove : :install
        box.pack_end(build_mark_toggle(atom: @package.atom, action: header_action,
                                       label: header_action == :remove ? 'Remove' : 'Install'),
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

      def badge(text, style_class)
        label = Gtk::Label.new(text)
        label.valign = :center
        label.style_context.add_class(style_class)
        label
      end

      ACTION_STYLE = {
        install: 'mark-install',
        upgrade: 'mark-upgrade',
        remove: 'mark-remove'
      }.freeze

      def build_mark_toggle(atom:, action:, label:, keyword_check: nil)
        toggle = Gtk::ToggleButton.new(label: label)
        toggle.valign = :center
        toggle.active = @marked_lookup.call(atom) == action
        toggle.style_context.add_class(ACTION_STYLE.fetch(action))
        toggle.signal_connect('toggled') do
          next if @updating

          @on_toggle.call(atom, action)
          # Marking a testing version without accepting its keyword would
          # just reproduce emerge's mask error; keep the two in step.
          keyword_check.active = toggle.active? if keyword_check&.sensitive?
        end
        toggle
      end

      def load_details
        return if @details_requested

        @details_requested = true
        loading = note_label('Loading details…')
        @detail_box.add(loading)
        @detail_box.show_all

        @detail_fetcher.fetch(@package.atom) do |details|
          loading.destroy
          render_details(details)
        end
      end

      def note_label(text)
        note = Gtk::Label.new(text)
        note.halign = :start
        note.style_context.add_class('slot-note')
        note
      end

      def render_details(details)
        render_slots(details.slots)
        render_use_flags(details.use_flags)
        @detail_box.show_all
      end

      def render_slots(options)
        if options.empty?
          @detail_box.add(note_label('No slot metadata available for this package'))
          return
        end

        options.each { |option| @detail_box.add(build_slot_row(option)) }
      end

      def build_slot_row(option)
        row = Gtk::Box.new(:horizontal, 12)
        row.style_context.add_class('slot-row')

        text = "slot #{option.slot} — #{option.newest_version}"
        text += " (installed: #{option.installed_version})" if option.installed
        label = Gtk::Label.new(text)
        label.halign = :start
        row.pack_start(label, expand: true, fill: true, padding: 0)

        row.pack_start(badge(option.needed_keyword == '**' ? 'unkeyworded' : '~testing', 'testing-badge'),
                       expand: false, fill: false, padding: 0) if option.needed_keyword
        row.pack_start(badge('installed', 'installed-badge'), expand: false, fill: false, padding: 0) if option.installed

        slotted_atom = "#{@package.atom}:#{option.slot}"
        keyword_check = build_keyword_check(slotted_atom, option)
        row.pack_start(keyword_check, expand: false, fill: false, padding: 0) if keyword_check

        if option.installed
          row.pack_end(build_mark_toggle(atom: slotted_atom, action: :remove, label: 'Remove'),
                       expand: false, fill: false, padding: 0)
          if option.upgrade_available
            row.pack_end(build_mark_toggle(atom: slotted_atom, action: :upgrade,
                                           label: "Upgrade → #{option.newest_version}",
                                           keyword_check: keyword_check),
                         expand: false, fill: false, padding: 0)
          end
        else
          row.pack_end(build_mark_toggle(atom: slotted_atom, action: :install, label: 'Install',
                                         keyword_check: keyword_check),
                       expand: false, fill: false, padding: 0)
        end
        row
      end

      # Shown when acting on this slot's newest version needs a keyword:
      # installing a testing slot, or upgrading to a testing version of an
      # installed one.
      def build_keyword_check(slotted_atom, option)
        return nil unless option.needed_keyword
        return nil if option.installed && !option.upgrade_available

        check = Gtk::CheckButton.new("accept #{option.needed_keyword}")
        check.style_context.add_class('keyword-check')

        foreign = option.accepted_by && option.accepted_by != 'zz-portland'
        check.active = foreign || option.accepted_by == 'zz-portland' ||
                       !@keyword_staged_lookup.call(slotted_atom).nil?
        if foreign
          check.sensitive = false
          check.tooltip_text = "Already accepted in /etc/portage/package.accept_keywords/#{option.accepted_by}"
        end

        check.signal_connect('toggled') do
          next if @updating

          @on_keyword_toggle.call(slotted_atom, check.active? ? option.needed_keyword : nil)
        end
        check
      end

      def render_use_flags(flags)
        return if flags.empty?

        @detail_box.add(note_label('USE flags'))

        flow = Gtk::FlowBox.new
        flow.selection_mode = :none
        flow.max_children_per_line = 6
        flow.column_spacing = 4
        flow.row_spacing = 2
        flow.homogeneous = false

        flags.each { |flag| flow.add(build_use_check(flag)) }
        @detail_box.add(flow)
      end

      def build_use_check(flag)
        check = Gtk::CheckButton.new(flag.name)
        staged = @use_staged_lookup.call(@package.atom, flag.name)
        check.active = staged.nil? ? flag.enabled : staged
        check.style_context.add_class('use-overridden') if flag.overridden? || !staged.nil?
        check.tooltip_text = use_tooltip(flag)

        check.signal_connect('toggled') do
          next if @updating

          desired = check.active?
          # An entry is only needed when the desired state differs from what
          # portage would do with no entry; an explicit entry from another
          # file always needs countering (zz-portland sorts last and wins).
          value = desired == flag.default_enabled && flag.source.nil? ? nil : desired
          @on_use_toggle.call(@package.atom, flag.name, value)

          if value.nil?
            check.style_context.remove_class('use-overridden')
          else
            check.style_context.add_class('use-overridden')
          end
        end
        check
      end

      def use_tooltip(flag)
        parts = [flag.description || 'No description available']
        parts << "Currently set in /etc/portage/package.use/#{flag.source}" if flag.source
        parts.join("\n")
      end
    end
  end
end
