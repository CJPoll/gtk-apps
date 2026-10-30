# frozen_string_literal: true

require_relative '../../test_helper'

# Parsing and presentation of `nvidia-smi -q -x`, against output captured
# from this machine's RTX 3080 (UUID redacted). The N/A fixture is the same
# capture with two processes' used_memory replaced by the driver's N/A forms.
class VramTest < Minitest::Test
  FIXTURES = File.expand_path('../../fixtures/bar', __dir__)
  Vram = Bar::Domain::Vram

  def fixture(name)
    File.read(File.join(FIXTURES, name))
  end

  def snapshot(name = 'nvidia_smi_q.xml')
    Vram.parse(fixture(name))
  end

  # --- parse -----------------------------------------------------------------

  def test_parse_reads_the_device_figures
    snap = snapshot

    assert_equal 'NVIDIA GeForce RTX 3080', snap.gpu_name
    assert_equal 10_240, snap.total_mib
    assert_equal 9254, snap.used_mib
  end

  def test_parse_lists_graphics_and_compute_processes
    procs = snapshot.processes

    assert_equal 9, procs.size
    llama = procs.find { |p| p.pid == 822_481 }
    assert_equal '/usr/local/lib/ollama/llama-server', llama.process_name
    assert_equal 7098, llama.used_mib
    assert_equal 'hyprland', procs.find { |p| p.pid == 706_242 }.process_name
  end

  def test_parse_keeps_na_processes_as_unknown_not_zero
    procs = snapshot('nvidia_smi_q_na.xml').processes

    assert_equal 9, procs.size, 'an N/A process must not be dropped'
    assert_nil procs.find { |p| p.pid == 21_194 }.used_mib
    assert_nil procs.find { |p| p.pid == 2_833_877 }.used_mib
  end

  def test_parse_with_no_processes
    snap = snapshot('nvidia_smi_q_no_processes.xml')

    assert_equal 9254, snap.used_mib
    assert_empty snap.processes
  end

  def test_parse_returns_nil_for_output_with_no_gpu
    assert_nil Vram.parse('')
    assert_nil Vram.parse('NVIDIA-SMI has failed because it could not communicate with the NVIDIA driver.')
    assert_nil Vram.parse(nil)
  end

  def test_parse_keeps_device_na_as_unknown
    xml = fixture('nvidia_smi_q.xml').sub('<used>9254 MiB</used>', '<used>N/A</used>')

    assert_nil Vram.parse(xml).used_mib
  end

  def test_parse_decodes_xml_entities_in_names
    xml = fixture('nvidia_smi_q.xml').sub('<process_name>hyprland</process_name>',
                                          '<process_name>a &amp; b</process_name>')

    assert_equal 'a & b', Vram.parse(xml).processes.find { |p| p.pid == 706_242 }.process_name
  end

  def test_parse_mib
    assert_equal 469, Vram.parse_mib('469 MiB')
    assert_nil Vram.parse_mib('N/A')
    assert_nil Vram.parse_mib('[N/A]')
    assert_nil Vram.parse_mib('')
    assert_nil Vram.parse_mib(nil)
  end

  # --- app names ---------------------------------------------------------------

  def test_app_name_prefers_the_live_comm_and_groups_browsers
    assert_equal 'Firefox', Vram.app_name(process_name: '/app/lib/firefox/firefox', comm: 'firefox-bin')
    assert_equal 'Firefox', Vram.app_name(process_name: '/app/lib/firefox/firefox', comm: 'Isolated Web Co')
    assert_equal 'Chrome', Vram.app_name(process_name: '/opt/google/chrome/chrome', comm: 'chrome')
  end

  def test_app_name_falls_back_to_the_reported_path_when_the_process_is_gone
    assert_equal 'llama-server', Vram.app_name(process_name: '/usr/local/lib/ollama/llama-server')
    assert_equal 'hyprland', Vram.app_name(process_name: 'hyprland', comm: nil)
  end

  def test_app_name_names_an_interpreter_by_its_script
    args = ['/usr/bin/ruby', '-r', 'bundler/setup', 'apps/bar/main.rb']

    assert_equal 'bar (ruby)', Vram.app_name(process_name: '/usr/bin/ruby', comm: 'ruby', args: args)
    assert_equal 'tool (python3)',
                 Vram.app_name(process_name: '/usr/bin/python3', comm: 'python3', args: %w[python3 -u tool.py])
    assert_equal 'ruby', Vram.app_name(process_name: '/usr/bin/ruby', comm: 'ruby', args: %w[ruby -e 1])
  end

  # --- aggregation -------------------------------------------------------------

  def test_top_apps_aggregates_by_app_and_sorts_by_usage
    procs = [
      Vram::GpuProcess.new(pid: 1, process_name: 'firefox', used_mib: 400),
      Vram::GpuProcess.new(pid: 2, process_name: 'llama-server', used_mib: 7000),
      Vram::GpuProcess.new(pid: 3, process_name: 'firefox', used_mib: 100, comm: 'Isolated Web Co')
    ]

    apps = Vram.top_apps(procs)

    assert_equal [['llama-server', 7000, 0], ['Firefox', 500, 0]], apps.map { |a| [a.name, a.used_mib, a.unknown] }
  end

  def test_top_apps_counts_na_processes_instead_of_zeroing_them
    procs = [
      Vram::GpuProcess.new(pid: 1, process_name: 'firefox', used_mib: 400),
      Vram::GpuProcess.new(pid: 2, process_name: 'firefox', used_mib: nil),
      Vram::GpuProcess.new(pid: 3, process_name: 'zoom', used_mib: nil)
    ]

    apps = Vram.top_apps(procs)

    assert_equal [['Firefox', 400, 1], ['zoom', nil, 1]], apps.map { |a| [a.name, a.used_mib, a.unknown] }
  end

  def test_top_apps_limits_the_list
    procs = (1..15).map { |i| Vram::GpuProcess.new(pid: i, process_name: "app#{i}", used_mib: i) }

    assert_equal 10, Vram.top_apps(procs).size
    assert_equal 'app15', Vram.top_apps(procs).first.name
  end

  # --- presentation ------------------------------------------------------------

  def test_percent
    assert_equal 90, Vram.percent(snapshot)
    assert_nil Vram.percent(Vram::Snapshot.new(gpu_name: 'x', total_mib: 10_240, used_mib: nil, processes: []))
    assert_nil Vram.percent(Vram::Snapshot.new(gpu_name: 'x', total_mib: 0, used_mib: 5, processes: []))
  end

  def test_label
    assert_equal '90% VRAM', Vram.label(snapshot)
    assert_equal 'n/a VRAM', Vram.label(Vram::Snapshot.new(gpu_name: 'x', total_mib: 10_240, used_mib: nil, processes: []))
  end

  def test_format_size_matches_the_ram_widget
    assert_equal '6.9G', Vram.format_size(7098)
    assert_equal '653M', Vram.format_size(653)
    assert_equal 'n/a', Vram.format_size(nil)
  end

  def test_tooltip_from_the_real_capture
    expected = <<~TIP.chomp
      VRAM: 90% (9.0G / 10.0G)
      GPU: NVIDIA GeForce RTX 3080

      === VRAM Hogs ===
         6.9G  llama-server
         653M  hyprland
         469M  Firefox
         134M  zoom
          77M  hyprpaper
          74M  alacritty
          32M  ruby
           5M  Xwayland
    TIP

    assert_equal expected, Vram.tooltip(snapshot)
  end

  def test_tooltip_surfaces_na_processes
    tip = Vram.tooltip(snapshot('nvidia_smi_q_na.xml'))

    assert_includes tip, "    n/a  Firefox\n"
    assert_includes tip, "    n/a  zoom\n"
    refute_match(/\b0M\b/, tip)
    assert_match(/2 processes report n\/a; their memory is still in the 9\.0G used/, tip)
  end

  def test_tooltip_marks_an_app_that_is_only_partly_known
    snap = Vram::Snapshot.new(gpu_name: 'g', total_mib: 1024, used_mib: 512, processes: [
                                Vram::GpuProcess.new(pid: 1, process_name: 'firefox', used_mib: 400),
                                Vram::GpuProcess.new(pid: 2, process_name: 'firefox', used_mib: nil)
                              ])

    assert_includes Vram.tooltip(snap), "   400M+ Firefox (1 n/a)"
  end

  def test_tooltip_with_no_processes
    tip = Vram.tooltip(snapshot('nvidia_smi_q_no_processes.xml'))

    assert_includes tip, "=== VRAM Hogs ===\n  (no GPU processes)"
  end

  def test_tooltip_with_unknown_device_usage
    snap = Vram::Snapshot.new(gpu_name: 'g', total_mib: 10_240, used_mib: nil, processes: [])

    assert_match(/\AVRAM: n\/a \(n\/a \/ 10\.0G\)/, Vram.tooltip(snap))
  end
end
