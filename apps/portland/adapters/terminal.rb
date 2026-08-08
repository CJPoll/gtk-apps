# frozen_string_literal: true

module Portland
  module Adapters
    # Runs a command in an interactive terminal window. Root work (emerge)
    # deliberately goes through here rather than running headless: sudo can
    # prompt, emerge --ask stays interactive, and the user sees the output.
    module Terminal
      module_function

      def run(shell_command)
        script = "#{shell_command}; status=$?; echo; " \
                 "read -rp \"Done (exit $status) - press enter to close \""
        # sudo -A hands password collection to our GUI helper instead of
        # prompting on the terminal.
        pid = spawn({ 'SUDO_ASKPASS' => askpass_path },
                    'alacritty', '--title', 'portland-task',
                    '-e', 'bash', '-c', script,
                    pgroup: true)
        Process.detach(pid)
      end

      def askpass_path
        File.join(GtkKit.root, 'bin', 'askpass')
      end
    end
  end
end
