# frozen_string_literal: true

require 'test_helper'

# Which live workspaces must be dispatched to another monitor after a save:
# hyprland's workspace rules bind only at workspace creation, so existing
# workspaces sitting on the wrong monitor need an explicit move.
class WorkspaceMovesTest < Minitest::Test
  MONITOR_NAMES = {
    'Dell U2718Q AAA' => 'DP-4',
    'Dell U2515H BBB' => 'DP-2'
  }.freeze

  def needed(assignments, live)
    HyprManager::Domain::WorkspaceMoves.needed(
      assignments, monitor_names: MONITOR_NAMES, live_workspaces: live
    )
  end

  def test_live_workspace_on_wrong_monitor_is_moved
    moves = needed({ 5 => 'Dell U2718Q AAA' }, [{ 'id' => 5, 'monitor' => 'DP-2' }])

    assert_equal [[5, 'DP-4']], moves
  end

  def test_live_workspace_already_on_assigned_monitor_is_not_moved
    moves = needed({ 5 => 'Dell U2718Q AAA' }, [{ 'id' => 5, 'monitor' => 'DP-4' }])

    assert_empty moves
  end

  def test_workspace_not_alive_is_not_moved
    # Dispatching a move for a nonexistent workspace would materialize it;
    # the creation-time rule covers it instead.
    moves = needed({ 5 => 'Dell U2718Q AAA' }, [])

    assert_empty moves
  end

  def test_assignment_to_unknown_monitor_is_skipped
    moves = needed({ 5 => 'LG Unplugged CCC' }, [{ 'id' => 5, 'monitor' => 'DP-2' }])

    assert_empty moves
  end

  def test_multiple_assignments_move_independently
    assignments = { 1 => 'Dell U2718Q AAA', 5 => 'Dell U2515H BBB' }
    live = [
      { 'id' => 1, 'monitor' => 'DP-4' },  # already right
      { 'id' => 5, 'monitor' => 'DP-4' }   # wrong monitor
    ]

    assert_equal [[5, 'DP-2']], needed(assignments, live)
  end

  def test_no_assignments_yield_no_moves
    assert_empty needed({}, [{ 'id' => 1, 'monitor' => 'DP-4' }])
  end
end
