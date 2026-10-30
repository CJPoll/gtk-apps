# frozen_string_literal: true

require_relative '../../test_helper'

# Sampling cadence and quiet degradation, with the nvidia-smi adapter and the
# clock faked.
class VramMonitorTest < Minitest::Test
  Vram = Bar::Domain::Vram
  Unavailable = Bar::Adapters::NvidiaSmi::Unavailable
  SNAPSHOT = Vram::Snapshot.new(gpu_name: 'g', total_mib: 10_240, used_mib: 9254, processes: [])

  # Plays back a script of results: a Snapshot is returned, an exception raised.
  class FakeSource
    attr_reader :calls

    def initialize(*script)
      @script = script
      @calls = 0
    end

    def sample
      @calls += 1
      step = @script.length > 1 ? @script.shift : @script.first
      step.is_a?(Exception) ? raise(step) : step
    end
  end

  def setup
    @now = 100.0
    @warnings = []
  end

  def monitor(source)
    Bar::Managers::VramMonitor.new(source: source, clock: -> { @now }, warn: ->(msg) { @warnings << msg })
  end

  def test_current_returns_the_sampled_snapshot
    assert_equal SNAPSHOT, monitor(FakeSource.new(SNAPSHOT)).current
  end

  # Several bars (one per monitor) share one sampler: a second ask inside the
  # max age reuses the snapshot instead of running nvidia-smi again.
  def test_reuses_a_fresh_snapshot
    source = FakeSource.new(SNAPSHOT)
    vram = monitor(source)

    vram.current
    @now += Bar::Managers::VramMonitor::MAX_AGE_SECONDS - 0.5
    vram.current

    assert_equal 1, source.calls
  end

  def test_resamples_once_stale
    source = FakeSource.new(SNAPSHOT)
    vram = monitor(source)

    vram.current
    @now += Bar::Managers::VramMonitor::MAX_AGE_SECONDS
    vram.current

    assert_equal 2, source.calls
  end

  def test_unavailable_is_nil_and_warns_once
    source = FakeSource.new(Unavailable.new('nvidia-smi not found'))
    vram = monitor(source)

    3.times do
      assert_nil vram.current
      @now += 10
    end

    assert_equal 3, source.calls
    assert_equal ['VramWidget: nvidia-smi not found'], @warnings
  end

  def test_an_unexpected_error_degrades_the_same_way
    vram = monitor(FakeSource.new(RuntimeError.new('boom')))

    assert_nil vram.current
    assert_equal 1, @warnings.size
    assert_match(/RuntimeError: boom/, @warnings.first)
  end

  def test_a_new_outage_after_recovery_warns_again
    source = FakeSource.new(Unavailable.new('down'), SNAPSHOT, Unavailable.new('down again'))
    vram = monitor(source)

    vram.current
    @now += 10
    assert_equal SNAPSHOT, vram.current
    @now += 10
    vram.current

    assert_equal ['VramWidget: down', 'VramWidget: down again'], @warnings
  end
end
