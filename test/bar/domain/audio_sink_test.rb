# frozen_string_literal: true

require_relative '../../test_helper'

class AudioSinkTest < Minitest::Test
  BEATGRIP_SINK = 'bluez_output.E1_3C_91_32_D2_FC.1'
  XM5_SINK = 'bluez_output.80_99_E7_F3_40_16.1'

  def test_bluetooth_is_decided_by_node_name
    assert Bar::Domain::AudioSink.bluetooth?(XM5_SINK)
    assert Bar::Domain::AudioSink.bluetooth?(BEATGRIP_SINK)
    refute Bar::Domain::AudioSink.bluetooth?('alsa_output.pci-0000_01_00.1.hdmi-stereo')
    refute Bar::Domain::AudioSink.bluetooth?(nil)
  end

  # Regression: with two bluetooth devices paired, picking the headphones must
  # address the headphones' own card, not whichever bluez card lists first.
  def test_card_name_follows_the_clicked_sink
    assert_equal 'bluez_card.80_99_E7_F3_40_16', Bar::Domain::AudioSink.card_name(XM5_SINK)
    assert_equal 'bluez_card.E1_3C_91_32_D2_FC', Bar::Domain::AudioSink.card_name(BEATGRIP_SINK)
  end

  def test_card_name_is_nil_for_a_non_bluetooth_sink
    assert_nil Bar::Domain::AudioSink.card_name('alsa_output.pci-0000_00_1f.3.iec958-stereo')
    assert_nil Bar::Domain::AudioSink.card_name(nil)
  end
end
