# frozen_string_literal: true

require 'shellwords'

module Portland
  module Domain
    # The set of packages marked for installation or removal, and the emerge
    # invocations that would carry the plan out. Pure bookkeeping: nothing
    # here touches portage.
    class EmergePlan
      def initialize
        @marks = {}
        @world_update = false
      end

      # Everything with an update at once: emerge -uDN @world.
      def toggle_world_update
        @world_update = !@world_update
      end

      def world_update?
        @world_update
      end

      # Marking an atom with its current action again unmarks it.
      def toggle(atom, action)
        if @marks[atom] == action
          @marks.delete(atom)
        else
          @marks[atom] = action
        end
      end

      def action_for(atom)
        @marks[atom]
      end

      def installs
        atoms_marked(:install)
      end

      def upgrades
        atoms_marked(:upgrade)
      end

      def removals
        atoms_marked(:remove)
      end

      def empty?
        @marks.empty? && !@world_update
      end

      def clear
        @marks.clear
        @world_update = false
      end

      def summary
        return 'Nothing marked' if empty?

        parts = []
        parts << 'world update' if @world_update
        parts << "#{installs.size} to install" if installs.any?
        parts << "#{upgrades.size} to upgrade" if upgrades.any?
        parts << "#{removals.size} to remove" if removals.any?
        parts.join(' · ')
      end

      # --ask keeps the final say in the terminal; --depclean removes a
      # package only if nothing else depends on it, which is the safe
      # default for interactive uninstalls. -A routes the password prompt
      # through the GUI askpass helper (Terminal sets SUDO_ASKPASS).
      #
      # rebuild_atoms: installed packages whose USE flags just changed
      # (RebuildPolicy). --oneshot keeps them out of world; --changed-use
      # --update makes the command a no-op for any package something earlier
      # in the pipeline already rebuilt with the new flags.
      def shell_commands(rebuild_atoms: [])
        commands = []
        commands << 'sudo -A emerge --ask --verbose --update --deep --newuse @world' if @world_update
        commands << "sudo -A emerge --ask --verbose #{escaped(installs)}" if installs.any?
        commands << "sudo -A emerge --ask --verbose --update #{escaped(upgrades)}" if upgrades.any?
        commands << "sudo -A emerge --ask --depclean #{escaped(removals)}" if removals.any?
        if rebuild_atoms.any?
          commands << "sudo -A emerge --ask --verbose --oneshot --changed-use --update #{escaped(rebuild_atoms)}"
        end
        commands
      end

      private

      def atoms_marked(action)
        @marks.select { |_, marked| marked == action }.keys
      end

      def escaped(atoms)
        atoms.map { |atom| Shellwords.escape(atom) }.join(' ')
      end
    end
  end
end
