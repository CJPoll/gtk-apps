# frozen_string_literal: true

require 'test_helper'

# Session-staged USE atoms: the packages whose USE flags were edited since
# load (or last save), i.e. the rebuild candidates for Apply.
class OverridesStagingTest < Minitest::Test
  def setup
    @overrides = Portland::Domain::Overrides.new
  end

  def test_staged_use_atoms_is_empty_initially
    assert_empty @overrides.staged_use_atoms
  end

  def test_set_use_stages_the_atom
    @overrides.set_use('gui-libs/gtk4-layer-shell', 'introspection', true)

    assert_equal ['gui-libs/gtk4-layer-shell'], @overrides.staged_use_atoms
  end

  def test_dropping_an_override_still_stages_the_atom
    # Removing an entry changes the package's effective flags too.
    @overrides.set_use('app-editors/vim', 'ruby', nil)

    assert_equal ['app-editors/vim'], @overrides.staged_use_atoms
  end

  def test_staged_atoms_are_deduplicated
    @overrides.set_use('app-editors/vim', 'ruby', true)
    @overrides.set_use('app-editors/vim', 'python', false)

    assert_equal ['app-editors/vim'], @overrides.staged_use_atoms
  end

  def test_multiple_packages_stage_independently
    @overrides.set_use('app-editors/vim', 'ruby', true)
    @overrides.set_use('app-shells/zsh', 'doc', true)

    assert_equal ['app-editors/vim', 'app-shells/zsh'], @overrides.staged_use_atoms.sort
  end

  def test_saved_clears_staged_atoms
    @overrides.set_use('app-editors/vim', 'ruby', true)
    @overrides.saved!

    assert_empty @overrides.staged_use_atoms
  end

  def test_keyword_staging_does_not_stage_a_use_atom
    # Keyword acceptance gates versions; it changes nothing about how an
    # installed copy was compiled.
    @overrides.set_keyword('dev-libs/foo:2', '~amd64')

    assert_empty @overrides.staged_use_atoms
  end

  def test_stable_unmask_does_not_stage_a_use_atom
    @overrides.set_stable_unmask('wayland')

    assert_empty @overrides.staged_use_atoms
  end

  def test_entries_loaded_from_disk_are_not_staged
    overrides = Portland::Domain::Overrides.new(
      use_content: "app-editors/vim ruby\ngui-libs/gtk4-layer-shell introspection\n"
    )

    assert_empty overrides.staged_use_atoms
  end
end
