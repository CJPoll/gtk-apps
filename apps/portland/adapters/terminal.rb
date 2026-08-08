# frozen_string_literal: true

module Portland
  module Adapters
    # Runs a command in an interactive terminal window. Root work (emerge)
    # deliberately goes through here rather than running headless: sudo can
    # prompt, emerge --ask stays interactive, and the user sees the output.
    module Terminal
      module_function

      # on_exit (optional) fires on the main loop once the terminal closes —
      # i.e. after the command finished AND the user dismissed the window,
      # so a refresh triggered from it sees post-emerge state.
      def run(shell_command, &on_exit)
        script = "#{shell_command}; status=$?; echo; " \
                 "read -rp \"Done (exit $status) - press enter to close \""
        # sudo -A hands password collection to our GUI helper instead of
        # prompting on the terminal.
        pid = spawn({ 'SUDO_ASKPASS' => askpass_path },
                    'alacritty', '--title', 'portland-task',
                    '-e', 'bash', '-c', script,
                    pgroup: true)
        notify_on_exit(Process.detach(pid), &on_exit)
      end

      def notify_on_exit(waiter, &on_exit)
        return unless on_exit

        Thread.new do
          waiter.value # the terminal's exit status; refresh happens regardless

          GLib::Idle.add do
            on_exit.call
            false
          end
        end
      end

      def askpass_path
        File.join(GtkKit.root, 'bin', 'askpass')
      end
    end
  end
end
