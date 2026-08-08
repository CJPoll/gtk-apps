# frozen_string_literal: true

require 'test_helper'

class EmergePlanTest < Minitest::Test
  def setup
    @plan = Portland::Domain::EmergePlan.new
  end

  def test_no_marks_and_no_rebuilds_yields_no_commands
    assert_empty @plan.shell_commands
  end

  def test_install_command_rendered_for_installs
    @plan.toggle('dev-libs/foo', :install)

    assert_equal ['sudo -A emerge --ask --verbose dev-libs/foo'], @plan.shell_commands
  end

  def test_rebuild_atoms_render_a_oneshot_changed_use_command
    commands = @plan.shell_commands(rebuild_atoms: ['gui-libs/gtk4-layer-shell'])

    assert_equal ['sudo -A emerge --ask --verbose --oneshot --changed-use --update gui-libs/gtk4-layer-shell'],
                 commands
  end

  def test_rebuild_atoms_are_shell_escaped
    commands = @plan.shell_commands(rebuild_atoms: ['>=dev-libs/foo-1.2'])

    assert_equal ['sudo -A emerge --ask --verbose --oneshot --changed-use --update \\>\\=dev-libs/foo-1.2'],
                 commands
  end

  def test_multiple_rebuild_atoms_share_one_command
    commands = @plan.shell_commands(rebuild_atoms: ['a/b', 'c/d'])

    assert_equal 1, commands.size
  end

  def test_rebuild_command_comes_after_plan_commands
    @plan.toggle('dev-libs/foo', :install)

    commands = @plan.shell_commands(rebuild_atoms: ['app-editors/vim'])

    assert_equal ['sudo -A emerge --ask --verbose dev-libs/foo',
                  'sudo -A emerge --ask --verbose --oneshot --changed-use --update app-editors/vim'],
                 commands
  end

  def test_no_rebuild_command_for_empty_rebuild_atoms
    @plan.toggle('dev-libs/foo', :install)

    assert_equal 1, @plan.shell_commands(rebuild_atoms: []).size
  end
end
