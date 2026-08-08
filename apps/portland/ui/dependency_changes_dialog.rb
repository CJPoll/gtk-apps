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

      # Runs modally. Returns {changes:, unmask_flags:} with the accepted
      # subset, or nil on cancel.
      def run_and_select
        show_all
        response = run

        selected = { changes: [], unmask_flags: [], extra_atoms: [] }
        @checks.each do |check, kind, payload|
          next unless check.active?

          case kind
          when :unmask then selected[:unmask_flags] << payload
          when :extra then selected[:extra_atoms] << payload
          else selected[:changes] << payload
          end
        end

        destroy
        response == Gtk::ResponseType::OK ? selected : nil
      end

      private

      def build(result)
        content_area.spacing = 8
        content_area.border_width = 12

        header = Gtk::Label.new(
          'Dependencies need configuration changes before this install can proceed. ' \
          'Accepted entries are written to portland-managed files under /etc/portage.'
        )
        header.halign = :start
        header.wrap = true
        content_area.pack_start(header, expand: false, fill: false, padding: 0)

        list = Gtk::Box.new(:vertical, 4)
        add_extra_atoms_section(list, result.extra_atoms)
        add_unmask_section(list, result.unmask_flags)
        add_change_section(list, 'package.accept_keywords', result.changes.select { |c| c.kind == :keyword })
        add_change_section(list, 'package.use', result.changes.select { |c| c.kind == :use })
        add_error_section(list, result.error) if result.error

        scrolled = Gtk::ScrolledWindow.new
        scrolled.set_policy(:never, :automatic)
        scrolled.add(list)
        content_area.pack_start(scrolled, expand: true, fill: true, padding: 0)
      end

      def section_label(text)
        label = Gtk::Label.new(text)
        label.halign = :start
        label.style_context.add_class('section-title')
        label
      end

      def note_label(text)
        note = Gtk::Label.new(text)
        note.halign = :start
        note.wrap = true
        note.style_context.add_class('dep-note')
        note
      end

      def add_extra_atoms_section(box, atoms)
        return if atoms.empty?

        box.pack_start(section_label('Additional packages to include'), expand: false, fill: false, padding: 4)
        atoms.each do |atom|
          check = Gtk::CheckButton.new(atom)
          check.active = true
          check.style_context.add_class('dep-change')
          @checks << [check, :extra, atom]
          box.pack_start(check, expand: false, fill: false, padding: 0)
          box.pack_start(note_label('upgraded in the same transaction to clear a blocker'),
                         expand: false, fill: false, padding: 0)
        end
      end

      def add_unmask_section(box, flags)
        return if flags.empty?

        box.pack_start(section_label('profile/use.stable.mask'), expand: false, fill: false, padding: 4)
        flags.each do |flag|
          check = Gtk::CheckButton.new("-#{flag}")
          check.active = true
          check.style_context.add_class('dep-change')
          @checks << [check, :unmask, flag]
          box.pack_start(check, expand: false, fill: false, padding: 0)
          box.pack_start(note_label('lifts the profile mask so stable packages can enable this flag'),
                         expand: false, fill: false, padding: 0)
        end
      end

      def add_change_section(box, title, changes)
        return if changes.empty?

        box.pack_start(section_label(title), expand: false, fill: false, padding: 4)
        changes.each do |change|
          check = Gtk::CheckButton.new(change.to_line)
          check.active = true
          check.style_context.add_class('dep-change')
          @checks << [check, :change, change]
          box.pack_start(check, expand: false, fill: false, padding: 0)

          next if change.required_by.empty?

          extra = change.required_by.size - 1
          text = "required by #{change.required_by.first}"
          text += " (+#{extra} more)" if extra.positive?
          box.pack_start(note_label(text), expand: false, fill: false, padding: 0)
        end
      end

      def add_error_section(box, error)
        box.pack_start(section_label('Unresolved by these changes'), expand: false, fill: false, padding: 4)
        message = Gtk::Label.new(error)
        message.halign = :start
        message.wrap = true
        message.style_context.add_class('dep-error')
        box.pack_start(message, expand: false, fill: false, padding: 0)
      end
    end
  end
end
