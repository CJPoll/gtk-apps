# frozen_string_literal: true

require 'test_helper'

# Contract test against the live installed-package database (read-only).
# sys-apps/portage is installed on every Gentoo system by definition.
class PortageCliInstalledTest < Minitest::Test
  def test_installed_package_is_installed
    assert Portland::Adapters::PortageCli.installed?('sys-apps/portage')
  end

  def test_unknown_package_is_not_installed
    refute Portland::Adapters::PortageCli.installed?('fake-category/no-such-package')
  end

  def test_slotted_atom_checks_that_slot
    slot = Portland::Adapters::PortageCli.installed_slots('sys-apps/portage').first

    assert Portland::Adapters::PortageCli.installed?("sys-apps/portage:#{slot}")
  end

  def test_slotted_atom_with_uninstalled_slot_is_not_installed
    refute Portland::Adapters::PortageCli.installed?('sys-apps/portage:no-such-slot')
  end
end
