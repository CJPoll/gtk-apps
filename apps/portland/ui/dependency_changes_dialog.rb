# frozen_string_literal: true

module Portland
  module UI
    # Presents the config changes emerge's resolver declared necessary —
    # keyword acceptances, USE changes, and profile stable-mask overrides —
    # each preselected, for the user to accept or trim before continuing.
    class DependencyChangesDialog < Gtk::Dialog
      def initialize(parent:, result:)
        super(title: 'Dependency changes required', parent: parent, flags: :modal,
              buttons: [['Cancel', :cancel], ['Accept & Continue', :ok]])
        set_default_size(700, 480)
        set_default_response(Gtk::ResponseType::OK)
        @checks = []

        build(result)

        # With unresolved errors on display, "Continue" is a gamble the user
        # should take knowingly.
        if result.error
          ok = get_widget_for_response(Gtk::ResponseType::OK)
          ok.label = 'Accept & Try Anyway'
        end
      end

      # Presents the dialog and yields once: {changes:, unmask_flags:,
      # extra_atoms:} with the accepted subset, or nil on cancel. GTK4 has no
      # blocking Dialog#run, so continuation code lives in the block.
      def choose(&block)
        signal_connect('response') do |_dialog, response|
          selected = collect_selected
          destroy
          block.call(response == Gtk::ResponseType::OK ? selected : nil)
        end
        present
      end

      private

      def collect_selected
        selected = { changes: [], unmask_flags: [], extra_atoms: [] }
        @checks.each do |check, kind, payload|
          next unless check.active?

          case kind
          when :unmask then selected[:unmask_flags] << payload
          when :extra then selected[:extra_atoms] << payload
          else selected[:changes] << payload
          end
        end
        selected
      end

      def build(result)
        content_area.spacing = 8
        content_area.margin_top = 12
        content_area.margin_bottom = 12
        content_area.margin_start = 12
        content_area.margin_end = 12

        header = Gtk::Label.new(
          'Dependencies need configuration changes before this install can proceed. ' \
          'Accepted entries are written to portland-managed files under /etc/portage.'
        )
        header.halign = :start
        header.wrap = true
        content_area.append(header)

        list = Gtk::Box.new(:vertical, 4)
        add_extra_atoms_section(list, result.extra_atoms)
        add_unmask_section(list, result.unmask_flags)
        add_change_section(list, 'package.accept_keywords', result.changes.select { |c| c.kind == :keyword })
        add_change_section(list, 'package.use', result.changes.select { |c| c.kind == :use })
        add_error_section(list, result.error) if result.error

        scrolled = Gtk::ScrolledWindow.new
        scrolled.set_policy(:never, :automatic)
        scrolled.child = list
        scrolled.vexpand = true
        content_area.append(scrolled)
      end

      def section_label(text)
        label = Gtk::Label.new(text)
        label.halign = :start
        label.margin_top = 4
        label.add_css_class('section-title')
        label
      end

      def note_label(text)
        note = Gtk::Label.new(text)
        note.halign = :start
        note.wrap = true
        note.add_css_class('dep-note')
        note
      end

      def add_extra_atoms_section(box, atoms)
        return if atoms.empty?

        box.append(section_label('Additional packages to include'))
        atoms.each do |atom|
          check = Gtk::CheckButton.new
          check.label = atom
          check.active = true
          check.add_css_class('dep-change')
          @checks << [check, :extra, atom]
          box.append(check)
          box.append(note_label('upgraded in the same transaction to clear a blocker'))
        end
      end

      def add_unmask_section(box, flags)
        return if flags.empty?

        box.append(section_label('profile/use.stable.mask'))
        flags.each do |flag|
          check = Gtk::CheckButton.new
          check.label = "-#{flag}"
          check.active = true
          check.add_css_class('dep-change')
          @checks << [check, :unmask, flag]
          box.append(check)
          box.append(note_label('lifts the profile mask so stable packages can enable this flag'))
        end
      end

      def add_change_section(box, title, changes)
        return if changes.empty?

        box.append(section_label(title))
        changes.each do |change|
          check = Gtk::CheckButton.new
          check.label = change.to_line
          check.active = true
          check.add_css_class('dep-change')
          @checks << [check, :change, change]
          box.append(check)

          next if change.required_by.empty?

          extra = change.required_by.size - 1
          text = "required by #{change.required_by.first}"
          text += " (+#{extra} more)" if extra.positive?
          box.append(note_label(text))
        end
      end

      def add_error_section(box, error)
        box.append(section_label('Unresolved by these changes'))
        message = Gtk::Label.new(error)
        message.halign = :start
        message.wrap = true
        message.add_css_class('dep-error')
        box.append(message)
      end
    end
  end
end
