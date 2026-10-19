# frozen_string_literal: true

require 'test_helper'

# What the "Identify screen" overlay says on a physical monitor. The number is
# the display's left-to-right slot, which is what the user sees on the card
# strip, so the overlay and the card can be matched at a glance.
class IdentifyLabelTest < Minitest::Test
  def monitor(name: 'DP-2', description: 'Dell Inc. DELL P2721Q 3V9PLH3', width: 3840, height: 2160, refresh: 59.997)
    HyprManager::Domain::Monitor.new(
      name: name, description: description, width: width, height: height,
      refresh: refresh, x: 0, y: 0, scale: 1.0, transform: 0, available_modes: []
    )
  end

  def label_for(mon, position)
    HyprManager::Domain::IdentifyLabel.for(mon, position: position)
  end

  def test_number_is_the_one_based_position
    assert_equal 1, label_for(monitor, 0).number
    assert_equal 3, label_for(monitor, 2).number
  end

  def test_port_is_the_current_connector_name
    assert_equal 'HDMI-A-2', label_for(monitor(name: 'HDMI-A-2'), 0).port
  end

  def test_model_drops_the_dell_prefix_but_keeps_the_serial
    assert_equal 'DELL P2721Q 3V9PLH3', label_for(monitor, 0).model
  end

  def test_model_keeps_the_whole_description_when_there_is_no_dell_prefix
    mon = monitor(description: 'Acme Panel 42')

    assert_equal 'Acme Panel 42', label_for(mon, 0).model
  end

  def test_detail_is_the_mode_string
    assert_equal '3840x2160@60', label_for(monitor, 0).detail
  end

  def test_rotated_monitor_still_reports_its_native_mode
    mon = monitor
    mon.transform = 1

    assert_equal '3840x2160@60', label_for(mon, 0).detail
  end
end
