# frozen_string_literal: true

require_relative '../../test_helper'

class BrightnessTest < Minitest::Test
  MAX_RAW = 62_194

  def test_to_percent_maps_the_raw_scale
    assert_equal 100, Bar::Domain::Brightness.to_percent(MAX_RAW, MAX_RAW)
    assert_equal 50, Bar::Domain::Brightness.to_percent(MAX_RAW / 2, MAX_RAW)
  end

  def test_to_percent_floors_at_the_minimum
    assert_equal 1, Bar::Domain::Brightness.to_percent(0, MAX_RAW)
  end

  def test_to_percent_survives_a_missing_max
    assert_equal 1, Bar::Domain::Brightness.to_percent(500, 0)
  end

  def test_to_raw_maps_back
    assert_equal MAX_RAW, Bar::Domain::Brightness.to_raw(100, MAX_RAW)
    assert_equal MAX_RAW / 2, Bar::Domain::Brightness.to_raw(50, MAX_RAW)
  end

  def test_to_raw_never_blanks_the_panel
    assert_operator Bar::Domain::Brightness.to_raw(0, MAX_RAW), :>, 0
    assert_operator Bar::Domain::Brightness.to_raw(-40, MAX_RAW), :>, 0
  end

  def test_round_trip_is_stable
    [1, 5, 25, 50, 75, 100].each do |percent|
      raw = Bar::Domain::Brightness.to_raw(percent, MAX_RAW)

      assert_equal percent, Bar::Domain::Brightness.to_percent(raw, MAX_RAW)
    end
  end

  def test_clamp_bounds_the_percent_scale
    assert_equal 1, Bar::Domain::Brightness.clamp(0)
    assert_equal 1, Bar::Domain::Brightness.clamp(-10)
    assert_equal 100, Bar::Domain::Brightness.clamp(150)
    assert_equal 42, Bar::Domain::Brightness.clamp(42)
  end

  def test_scroll_step_brightens_on_scroll_up
    assert_equal 5, Bar::Domain::Brightness.scroll_step(-1.0, 5)
  end

  def test_scroll_step_dims_on_scroll_down
    assert_equal(-5, Bar::Domain::Brightness.scroll_step(1.0, 5))
  end

  # A kinetic or stop event carries a zero delta. Reading that as a direction
  # is what silently dimmed the panel to its floor.
  def test_scroll_step_ignores_a_zero_delta
    assert_equal 0, Bar::Domain::Brightness.scroll_step(0.0, 5)
    assert_equal 0, Bar::Domain::Brightness.scroll_step(0, 5)
  end

  def test_icon_steps_with_the_level
    assert_equal '󰃠', Bar::Domain::Brightness.icon(100)
    assert_equal '󰃠', Bar::Domain::Brightness.icon(75)
    assert_equal '󰃟', Bar::Domain::Brightness.icon(74)
    assert_equal '󰃟', Bar::Domain::Brightness.icon(50)
    assert_equal '󰃞', Bar::Domain::Brightness.icon(49)
    assert_equal '󰃞', Bar::Domain::Brightness.icon(25)
    assert_equal '󰃝', Bar::Domain::Brightness.icon(24)
    assert_equal '󰃝', Bar::Domain::Brightness.icon(1)
  end

  def test_label_pairs_icon_and_percent
    assert_equal '󰃠 80%', Bar::Domain::Brightness.label(80)
  end
end
