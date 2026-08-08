# frozen_string_literal: true

require 'gtk4'

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
    content.margin_top = 12
    content.margin_bottom = 12
    content.margin_start = 12
    content.margin_end = 12
    content.append(label)
    content.append(entry)

    [dialog, entry]
  end

  # Returns the process exit status: 0 with the password on stdout, 1 on
  # cancel (sudo aborts cleanly on non-zero).
  #
  # GTK4 removed blocking Dialog#run; a nested main loop restores the only
  # behavior this program has: wait for the answer, then exit.
  def run(prompt)
    Gtk.init if Gtk.respond_to?(:init)
    dialog, entry = build_dialog(prompt)

    response = nil
    main_loop = GLib::MainLoop.new
    dialog.signal_connect('response') do |_dialog, dialog_response|
      response = dialog_response
      main_loop.quit
    end
    dialog.signal_connect('close-request') do
      main_loop.quit
      false
    end
    dialog.present
    main_loop.run

    if response == Gtk::ResponseType::OK
      $stdout.puts(entry.text)
      $stdout.flush
      0
    else
      1
    end
  ensure
    dialog&.destroy
  end
end

exit Askpass.run(ARGV.first || 'Password:') if $PROGRAM_NAME == __FILE__
