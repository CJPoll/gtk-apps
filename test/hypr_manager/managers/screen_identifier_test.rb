# frozen_string_literal: true

require 'test_helper'

# Orchestration of "Identify screen": resolve the card's monitor to the live
# output, find its GDK handle, and put an overlay on exactly that output.
# Hyprland, GDK and GTK are all faked; nothing here needs a display.
class ScreenIdentifierTest < Minitest::Test
  DESC_A = 'Dell Inc. DELL U2718Q AAA'
  DESC_B = 'Dell Inc. DELL P2721Q BBB'

  FakeIpc = Struct.new(:monitors)

  class FakeGdk
    attr_reader :by_connector_calls, :by_position_calls

    def initialize(connectors: {}, positions: {})
      @connectors = connectors
      @positions = positions
      @by_connector_calls = []
      @by_position_calls = []
    end

    def find_by_connector(name)
      @by_connector_calls << name
      @connectors[name]
    end

    def find_by_position(x, y)
      @by_position_calls << [x, y]
      @positions[[x, y]]
    end
  end

  class FakeOverlay
    attr_reader :closed

    def initialize
      @closed = 0
    end

    def close
      @closed += 1
    end
  end

  def setup
    @shown = []
    @overlays = []
    @maker = lambda do |label, gdk_monitor|
      @shown << [label, gdk_monitor]
      overlay = FakeOverlay.new
      @overlays << overlay
      overlay
    end
  end

  def hypr(name, description, x: 0, y: 0, disabled: false)
    { 'name' => name, 'description' => description, 'x' => x, 'y' => y, 'disabled' => disabled,
      'width' => 3840, 'height' => 2160, 'refreshRate' => 60.0, 'scale' => 1.0, 'transform' => 0 }
  end

  def monitor(name, description)
    HyprManager::Domain::Monitor.new(
      name: name, description: description, width: 3840, height: 2160,
      refresh: 60.0, x: 0, y: 0, scale: 1.0, transform: 0, available_modes: []
    )
  end

  def identifier(live, gdk)
    HyprManager::Managers::ScreenIdentifier.new(
      ipc: FakeIpc.new(live), gdk: gdk, overlay_maker: @maker
    )
  end

  def test_shows_the_overlay_on_the_gdk_monitor_of_the_live_connector
    gdk_b = Object.new
    gdk = FakeGdk.new(connectors: { 'DP-2' => gdk_b, 'DP-4' => Object.new })
    live = [hypr('DP-4', DESC_A), hypr('DP-2', DESC_B)]

    result = identifier(live, gdk).identify(monitor('STALE', DESC_B), position: 1)

    assert_equal :shown, result
    label, shown_on = @shown.first
    assert_same gdk_b, shown_on
    assert_equal 2, label.number
    assert_equal 'DP-2', label.port
  end

  def test_card_is_matched_by_description_not_by_a_possibly_stale_port_name
    gdk = FakeGdk.new(connectors: { 'DP-9' => :out })
    live = [hypr('DP-9', DESC_A)]

    identifier(live, gdk).identify(monitor('DP-1', DESC_A), position: 0)

    assert_equal ['DP-9'], gdk.by_connector_calls
  end

  def test_label_uses_the_live_port_name
    gdk = FakeGdk.new(connectors: { 'DP-9' => :out })

    identifier([hypr('DP-9', DESC_A)], gdk).identify(monitor('DP-1', DESC_A), position: 0)

    assert_equal 'DP-9', @shown.first.first.port
  end

  def test_label_shows_the_live_mode_not_the_cards_unsaved_edit
    gdk = FakeGdk.new(connectors: { 'DP-2' => :out })
    edited = monitor('DP-2', DESC_A)
    edited.apply_mode('1920x1080@60.00Hz')

    identifier([hypr('DP-2', DESC_A)], gdk).identify(edited, position: 0)

    assert_equal '3840x2160@60', @shown.first.first.detail
  end

  def test_connector_match_wins_over_position
    gdk = FakeGdk.new(connectors: { 'DP-2' => :by_connector }, positions: { [0, 0] => :by_position })

    identifier([hypr('DP-2', DESC_A)], gdk).identify(monitor('DP-2', DESC_A), position: 0)

    assert_equal :by_connector, @shown.first.last
    assert_empty gdk.by_position_calls
  end

  def test_falls_back_to_position_when_gdk_has_no_connector_match
    gdk = FakeGdk.new(positions: { [3840, 0] => :by_position })
    live = [hypr('HDMI-A-2', DESC_A, x: 3840)]

    result = identifier(live, gdk).identify(monitor('HDMI-A-2', DESC_A), position: 0)

    assert_equal :shown, result
    assert_equal :by_position, @shown.first.last
  end

  def test_monitor_not_connected_shows_nothing
    gdk = FakeGdk.new(connectors: { 'DP-2' => :out })

    result = identifier([hypr('DP-2', DESC_B)], gdk).identify(monitor('DP-4', DESC_A), position: 0)

    assert_equal :not_connected, result
    assert_empty @shown
  end

  def test_disabled_monitor_counts_as_not_connected
    gdk = FakeGdk.new(connectors: { 'DP-2' => :out })

    result = identifier([hypr('DP-2', DESC_A, disabled: true)], gdk).identify(monitor('DP-2', DESC_A), position: 0)

    assert_equal :not_connected, result
    assert_empty @shown
  end

  def test_output_gdk_has_not_enumerated_yet_shows_nothing
    result = identifier([hypr('DP-2', DESC_A)], FakeGdk.new).identify(monitor('DP-2', DESC_A), position: 0)

    assert_equal :no_output, result
    assert_empty @shown
  end

  def test_overlay_maker_declining_reports_unsupported
    @maker = ->(_label, _gdk_monitor) {}
    gdk = FakeGdk.new(connectors: { 'DP-2' => :out })

    result = identifier([hypr('DP-2', DESC_A)], gdk).identify(monitor('DP-2', DESC_A), position: 0)

    assert_equal :unsupported, result
  end

  def test_unsupported_reclick_leaves_the_existing_overlay_up
    gdk = FakeGdk.new(connectors: { 'DP-2' => :out })
    supported = true
    @maker = lambda do |_label, _gdk_monitor|
      next unless supported

      FakeOverlay.new.tap { |overlay| @overlays << overlay }
    end
    subject = identifier([hypr('DP-2', DESC_A)], gdk)
    subject.identify(monitor('DP-2', DESC_A), position: 0)

    supported = false
    result = subject.identify(monitor('DP-2', DESC_A), position: 0)

    assert_equal :unsupported, result
    assert_equal [0], @overlays.map(&:closed)
  end

  def test_identifying_the_same_monitor_again_replaces_its_overlay
    gdk = FakeGdk.new(connectors: { 'DP-2' => :out })
    subject = identifier([hypr('DP-2', DESC_A)], gdk)

    subject.identify(monitor('DP-2', DESC_A), position: 0)
    subject.identify(monitor('DP-2', DESC_A), position: 0)

    assert_equal [1, 0], @overlays.map(&:closed)
  end

  def test_identifying_different_monitors_keeps_both_overlays_up
    gdk = FakeGdk.new(connectors: { 'DP-2' => :a, 'DP-4' => :b })
    subject = identifier([hypr('DP-2', DESC_A), hypr('DP-4', DESC_B)], gdk)

    subject.identify(monitor('DP-2', DESC_A), position: 0)
    subject.identify(monitor('DP-4', DESC_B), position: 1)

    assert_equal [0, 0], @overlays.map(&:closed)
  end

  def test_close_all_dismisses_every_overlay
    gdk = FakeGdk.new(connectors: { 'DP-2' => :a, 'DP-4' => :b })
    subject = identifier([hypr('DP-2', DESC_A), hypr('DP-4', DESC_B)], gdk)
    subject.identify(monitor('DP-2', DESC_A), position: 0)
    subject.identify(monitor('DP-4', DESC_B), position: 1)

    subject.close_all

    assert_equal [1, 1], @overlays.map(&:closed)
  end
end
