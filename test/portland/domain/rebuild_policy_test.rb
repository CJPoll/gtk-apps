# frozen_string_literal: true

require 'test_helper'

# Which staged-USE atoms need an explicit recompile when Apply runs.
class RebuildPolicyTest < Minitest::Test
  ALL_INSTALLED = ->(_atom) { true }

  def setup
    @plan = Portland::Domain::EmergePlan.new
  end

  def rebuilds(staged, installed: ALL_INSTALLED)
    Portland::Domain::RebuildPolicy.atoms(staged, plan: @plan, installed: installed)
  end

  def test_staged_installed_atom_is_rebuilt
    assert_equal ['gui-libs/gtk4-layer-shell'], rebuilds(['gui-libs/gtk4-layer-shell'])
  end

  def test_uninstalled_atom_is_not_rebuilt
    # Staging USE for a package before installing it must not install it.
    assert_empty rebuilds(['gui-libs/gtk4-layer-shell'], installed: ->(_) { false })
  end

  def test_installed_filter_applies_per_atom
    installed = ->(atom) { atom == 'app-editors/vim' }

    assert_equal ['app-editors/vim'],
                 rebuilds(['app-editors/vim', 'dev-libs/foo'], installed: installed)
  end

  def test_atom_marked_for_install_is_not_rebuilt
    # The pending install compiles with the new flags already.
    @plan.toggle('gui-libs/gtk4-layer-shell', :install)

    assert_empty rebuilds(['gui-libs/gtk4-layer-shell'])
  end

  def test_atom_marked_for_upgrade_is_not_rebuilt
    @plan.toggle('app-editors/vim', :upgrade)

    assert_empty rebuilds(['app-editors/vim'])
  end

  def test_atom_marked_for_removal_is_still_rebuilt
    # A removal elsewhere in the plan says nothing about this package's
    # staged flags; the atoms differ, so both actions proceed.
    @plan.toggle('dev-libs/foo', :remove)

    assert_equal ['app-editors/vim'], rebuilds(['app-editors/vim'])
  end

  def test_slotted_plan_entry_covers_the_bare_staged_atom
    @plan.toggle('dev-lang/python:3.13', :upgrade)

    assert_empty rebuilds(['dev-lang/python'])
  end

  def test_bare_plan_entry_covers_the_slotted_staged_atom
    @plan.toggle('dev-lang/python', :install)

    assert_empty rebuilds(['dev-lang/python:3.13'])
  end

  def test_versioned_spec_matches_plan_entry_for_same_package
    # Dependency-dialog staging uses specs like ">=cat/name-1.2".
    @plan.toggle('dev-libs/foo', :install)

    assert_empty rebuilds(['>=dev-libs/foo-1.2.3'])
  end

  def test_version_stripping_keeps_digits_in_package_names
    assert_equal ['gui-libs/gtk4-layer-shell'], rebuilds(['gui-libs/gtk4-layer-shell'])
  end

  def test_world_update_rebuilds_nothing_explicitly
    # emerge --update --deep --newuse @world already rebuilds USE changes.
    @plan.toggle_world_update

    assert_empty rebuilds(['app-editors/vim'])
  end

  def test_empty_staged_list_yields_no_rebuilds
    assert_empty rebuilds([])
  end
end
