# frozen_string_literal: true

require 'test_helper'

# Happy path, no mocks (read-only against the live package database):
# staging a USE flag for an installed package with nothing else marked
# must produce a rebuild emerge on Apply — the exact scenario that
# motivated the feature (gtk4-layer-shell needed USE=introspection).
class UseRebuildIntegrationTest < Minitest::Test
  def test_use_edit_on_installed_package_yields_rebuild_command
    overrides = Portland::Domain::Overrides.new
    plan = Portland::Domain::EmergePlan.new

    overrides.set_use('sys-apps/portage', 'doc', true)

    rebuilds = Portland::Domain::RebuildPolicy.atoms(
      overrides.staged_use_atoms,
      plan: plan,
      installed: ->(atom) { Portland::Adapters::PortageCli.installed?(atom) }
    )
    commands = plan.shell_commands(rebuild_atoms: rebuilds)

    assert_equal ['sudo -A emerge --ask --verbose --oneshot --changed-use --update sys-apps/portage'],
                 commands
  end

  def test_use_edit_on_uninstalled_package_yields_no_commands
    overrides = Portland::Domain::Overrides.new
    plan = Portland::Domain::EmergePlan.new

    overrides.set_use('fake-category/no-such-package', 'doc', true)

    rebuilds = Portland::Domain::RebuildPolicy.atoms(
      overrides.staged_use_atoms,
      plan: plan,
      installed: ->(atom) { Portland::Adapters::PortageCli.installed?(atom) }
    )

    assert_empty plan.shell_commands(rebuild_atoms: rebuilds)
  end
end
