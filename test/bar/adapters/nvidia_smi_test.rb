# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'
require 'fileutils'

# The adapter with an injected command runner and a fake /proc: no real
# nvidia-smi, no GPU work.
class NvidiaSmiTest < Minitest::Test
  FIXTURES = File.expand_path('../../fixtures/bar', __dir__)
  NvidiaSmi = Bar::Adapters::NvidiaSmi
  Result = NvidiaSmi::Result

  def setup
    @proc_root = Dir.mktmpdir('vram-proc')
    @xml = File.read(File.join(FIXTURES, 'nvidia_smi_q.xml'))
  end

  def teardown
    FileUtils.remove_entry(@proc_root)
  end

  def fake_proc(pid, comm:, args:)
    dir = File.join(@proc_root, pid.to_s)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'comm'), "#{comm}\n")
    File.write(File.join(dir, 'cmdline'), "#{args.join("\0")}\0")
  end

  def adapter(result)
    calls = []
    runner = lambda do |command|
      calls << command
      result.is_a?(Exception) ? raise(result) : result
    end
    [NvidiaSmi.new(runner: runner, proc_root: @proc_root), calls]
  end

  def test_sample_runs_one_query_and_parses_it
    smi, calls = adapter(Result.new(stdout: @xml, stderr: '', success: true))

    snap = smi.sample

    assert_equal 1, calls.size
    assert_equal %w[nvidia-smi -q -x], calls.first.last(3)
    assert_equal 9254, snap.used_mib
    assert_equal 9, snap.processes.size
  end

  def test_sample_reads_comm_and_cmdline_of_live_processes
    fake_proc(1_063_723, comm: 'ruby', args: ['/usr/bin/ruby', '-r', 'bundler/setup', 'apps/bar/main.rb'])
    fake_proc(21_194, comm: 'firefox-bin', args: ['/app/lib/firefox/firefox'])
    smi, = adapter(Result.new(stdout: @xml, stderr: '', success: true))

    procs = smi.sample.processes.to_h { |p| [p.pid, p] }

    assert_equal 'ruby', procs[1_063_723].comm
    assert_equal ['/usr/bin/ruby', '-r', 'bundler/setup', 'apps/bar/main.rb'], procs[1_063_723].args
    assert_equal 'firefox-bin', procs[21_194].comm
  end

  def test_a_process_gone_from_proc_keeps_nvidia_smis_name
    smi, = adapter(Result.new(stdout: @xml, stderr: '', success: true))

    llama = smi.sample.processes.find { |p| p.pid == 822_481 }

    assert_nil llama.comm
    assert_nil llama.args
    assert_equal '/usr/local/lib/ollama/llama-server', llama.process_name
  end

  def test_missing_binary_is_unavailable
    smi, = adapter(Errno::ENOENT.new('nvidia-smi'))

    error = assert_raises(NvidiaSmi::Unavailable) { smi.sample }
    assert_match(/not found/, error.message)
  end

  def test_failed_run_is_unavailable_with_its_first_error_line
    msg = "NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver.\nMore text\n"
    smi, = adapter(Result.new(stdout: msg, stderr: '', success: false))

    error = assert_raises(NvidiaSmi::Unavailable) { smi.sample }
    assert_match(/couldn't communicate/, error.message)
    refute_match(/More text/, error.message)
  end

  def test_output_with_no_gpu_is_unavailable
    smi, = adapter(Result.new(stdout: '<nvidia_smi_log></nvidia_smi_log>', stderr: '', success: true))

    assert_raises(NvidiaSmi::Unavailable) { smi.sample }
  end

  # The one unmocked path: the real binary, read-only query. Skipped where
  # there is no nvidia-smi (CI, a non-NVIDIA machine).
  def test_real_nvidia_smi_when_present
    skip 'nvidia-smi not installed' unless ENV['PATH'].to_s.split(':').any? { |d| File.executable?(File.join(d, 'nvidia-smi')) }

    snap = NvidiaSmi.new.sample

    assert_operator snap.total_mib, :>, 0
    refute_empty snap.gpu_name
  rescue NvidiaSmi::Unavailable => e
    skip "nvidia-smi present but unavailable: #{e.message}"
  end
end
