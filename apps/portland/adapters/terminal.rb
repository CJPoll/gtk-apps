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
        pid = spawn('alacritty', '--title', 'portland-task',
                    '-e', 'bash', '-c', script,
                    pgroup: true)
        Process.detach(pid)
      end
    end
  end
end
