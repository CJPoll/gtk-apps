# frozen_string_literal: true

module Portland
  module Managers
    # Runs emerge's own resolver (pretend + autounmask) against a sandbox
    # copy of /etc/portage with staged config applied, iterating until it
    # reaches a fixed point:
    #
    #   - autounmask suggestions are staged into the sandbox and resolution
    #     re-runs, so multi-step chains (keyword one dep, which exposes the
    #     next) all surface before anything touches the real system;
    #   - "no ebuilds can satisfy pkg[flag]" failures where the flag is
    #     profile stable-masked stage a use.stable.mask override and re-run —
    #     the case autounmask itself gives up on.
    #
    # The accumulated changes are reported for the user to accept; nothing
    # here mutates the caller's Overrides or the real config.
    class DependencyResolver
      MAX_ROUNDS = 6

      Result = Struct.new(:changes, :unmask_flags, :extra_atoms, :error, :clean,
                          keyword_init: true) do
        def anything?
          changes.any? || unmask_flags.any? || extra_atoms.any?
        end
      end

      def resolve(atoms, overrides, world_update: false, &on_result)
        Thread.new do
          result = resolve_sync(atoms, overrides, world_update)

          GLib::Idle.add do
            on_result.call(result)
            false
          end
        end
      end

      private

      def resolve_sync(atoms, overrides, world_update)
        atoms = atoms.dup
        work = clone_overrides(overrides)
        changes = []
        unmask_flags = []
        extra_atoms = []
        error = nil
        clean = false

        MAX_ROUNDS.times do
          output = pretend(atoms, work, world_update)

          round_changes = Domain::AutounmaskParser.parse(output)
          if round_changes.any?
            round_changes.each { |change| stage(work, change) }
            changes.concat(round_changes)
            next
          end

          liftable = Domain::AutounmaskParser.unsatisfiable_flags(output)
                                             .reject { |flag| unmask_flags.include?(flag) }
                                             .select { |flag| Adapters::PortageCli.stable_masked_flag?(flag) }
          if liftable.any?
            liftable.each { |flag| work.set_stable_unmask(flag) }
            unmask_flags.concat(liftable)
            next
          end

          # An unsatisfied soft block clears by upgrading the blocking
          # package in the same transaction; add it and re-resolve.
          blockers = Domain::AutounmaskParser.soft_blockers(output)
                                             .reject { |atom| atoms.include?(atom) }
          if blockers.any?
            extra_atoms.concat(blockers)
            atoms.concat(blockers)
            next
          end

          error = Domain::AutounmaskParser.resolution_error(output)
          clean = error.nil?
          break
        end

        Result.new(changes: changes, unmask_flags: unmask_flags,
                   extra_atoms: extra_atoms, error: error, clean: clean)
      end

      def pretend(atoms, work, world_update)
        sandbox = Adapters::ResolutionSandbox.build(
          use_content: work.render_use,
          keywords_content: work.render_keywords,
          stable_unmask_content: work.render_stable_unmask
        )
        Adapters::PortageCli.pretend_install(atoms, configroot: sandbox, world_update: world_update)
      end

      # Render/parse round trip: a private working copy the loop can stage
      # suggestions into without touching the caller's model.
      def clone_overrides(overrides)
        Domain::Overrides.new(
          use_content: overrides.render_use,
          keywords_content: overrides.render_keywords,
          stable_unmask_content: overrides.render_stable_unmask
        )
      end

      def stage(work, change)
        if change.kind == :keyword
          work.set_keyword(change.atom_spec, change.tokens.first)
        else
          change.tokens.each do |token|
            work.set_use(change.atom_spec, token.delete_prefix('-'), !token.start_with?('-'))
          end
        end
      end
    end
  end
end
