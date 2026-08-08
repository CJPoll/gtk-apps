# frozen_string_literal: true

require 'gtk3'

# Minimal SUDO_ASKPASS helper: sudo invokes this with its prompt as ARGV[0],
# reads the password from stdout, and treats a non-zero exit as cancellation.
# Deliberately self-contained — no Zeitwerk, no app framework — so the only
# thing between sudo and the dialog is GTK startup.
module Askpass
  TITLE = 'Authentication required'

  module_function

  def build_dialog(prompt)
    Gtk::Settings.default.gtk_application_prefer_dark_theme = true

    dialog = Gtk::Dialog.new(
      title: TITLE,
      flags: :modal,
      buttons: [['Cancel', :cancel], ['OK', :ok]]
    )
    dialog.set_default_size(380, -1)
    dialog.set_default_response(Gtk::ResponseType::OK)

    label = Gtk::Label.new(prompt)
    label.halign = :start

    entry = Gtk::Entry.new
    entry.visibility = false
    entry.input_purpose = :password
    entry.activates_default = true

    content = dialog.content_area
    content.spacing = 8
    content.border_width = 12
    content.pack_start(label, expand: false, fill: false, padding: 0)
    content.pack_start(entry, expand: false, fill: false, padding: 0)

    [dialog, entry]
  end

  # Returns the process exit status: 0 with the password on stdout, 1 on
  # cancel (sudo aborts cleanly on non-zero).
  def run(prompt)
    dialog, entry = build_dialog(prompt)
    dialog.show_all
    response = dialog.run

    if response == Gtk::ResponseType::OK
      $stdout.puts(entry.text)
      $stdout.flush
      0
    else
      1
    end
  ensure
    dialog.destroy
  end
end

exit Askpass.run(ARGV.first || 'Password:') if $PROGRAM_NAME == __FILE__
