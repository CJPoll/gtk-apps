# frozen_string_literal: true

require 'shellwords'

module Portland
  module Adapters
    # Read-only portage queries via portage-utils. Anything that mutates the
    # system goes through Terminal instead, where the user can authorize it.
    module PortageCli
      module_function

      # qsearch treats name search (-s) and description search (-S) as
      # separate modes, so run both; the parser dedups overlapping atoms.
      def search(query)
        escaped = Shellwords.escape(query)
        names = `qsearch -s -- #{escaped} 2>/dev/null`
        descriptions = `qsearch -S -- #{escaped} 2>/dev/null`
        names + descriptions
      rescue Errno::ENOENT
        ''
      end

      def installed_atoms
        `qlist -I 2>/dev/null`.split("\n")
      rescue Errno::ENOENT
        []
      end
    end
  end
end
