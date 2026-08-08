# frozen_string_literal: true

module Portland
  module Domain
    # Decides which staged-USE atoms need an explicit recompile when a plan
    # is applied. Pure: installed-ness is injected as a predicate so the
    # decision stays testable without touching portage.
    module RebuildPolicy
      module_function

      # staged_atoms: atoms whose USE flags were edited (Overrides#staged_use_atoms)
      # plan:         the EmergePlan about to run
      # installed:    callable(atom) -> bool
      #
      # Excluded:
      # - everything, when a world update is marked (--newuse @world already
      #   rebuilds USE changes)
      # - packages the plan installs or upgrades (they compile with the new
      #   flags as part of that action)
      # - packages that are not installed (staging flags ahead of an install
      #   must not become an install)
      def atoms(staged_atoms, plan:, installed:)
        return [] if plan.world_update?

        planned = (plan.installs + plan.upgrades).map { |atom| base_atom(atom) }

        staged_atoms
          .reject { |atom| planned.include?(base_atom(atom)) }
          .select { |atom| installed.call(atom) }
      end

      # "category/name" from any atom spec: strips version operators
      # (>=cat/name-1.2), slot suffixes (cat/name:3), or both. The version
      # segment is the last hyphen-digit run, so names containing digits
      # (gtk4-layer-shell) survive intact.
      def base_atom(atom_spec)
        atom_spec
          .sub(/\A[<>=~]+/, '')
          .sub(/:[^:]*\z/, '')
          .sub(%r{-\d[^/-]*(-r\d+)?\z}, '')
      end
    end
  end
end
