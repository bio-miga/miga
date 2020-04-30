require 'test_helper'
require 'miga/lair'

class LairTest < Test::Unit::TestCase
  include TestHelper

  def setup
    initialize_miga_home(
      <<~DAEMON
        { "maxjobs": 1, "ppn": 1, "latency": 1, "varsep": " ",
          "var": "{{key}}={{value}}", "cmd": "echo {{task_name}} >/dev/null",
          "alive": "echo 1 # {{pid}}", "type": "bash", "format_version": 1 }
      DAEMON
    )

    # Make sure projects already exist
    Dir.mkdir(tmpfile('sub'))
    project(1)
    project(2)
    project('sub/project3')
  end

  def test_lair_init
    path = tmpdir
    lair = MiGA::Lair.new(path, name: 'Alt-X')
    assert_equal(MiGA::Lair, lair.class)
    assert_equal(path, lair.path)
    assert_equal(path, lair.daemon_home)
    assert_equal('MiGA:Alt-X', lair.daemon_name)
    assert_equal(lair.daemon_home, MiGA::Lair.daemon_home(lair.daemon_home))
  end

  def test_in_loop
    declare_forks
    lair = MiGA::Lair.new(tmpdir, name: 'Oh')
    child = lair.start(['--shush'])
    assert_not_nil(child)
    assert_gt(child, 0, 'The daemon process should have non-zero PID')
    sleep(2)
    capture_stderr { lair.stop }
    assert_raise(Errno::ESRCH) { Process.kill(0, child) }
    assert_nil(lair.declare_alive_pid)
    assert_path_exist(lair.output_file)
    l = File.readlines(lair.output_file)
    assert_match(/-{20}\n/, l[0])
    assert_match(/MiGA:Oh launched\n/, l[1])
  end

  def test_first_loop
    lair = MiGA::Lair.new(tmpdir, name: 'Ew')
    out = capture_stderr { lair.daemon_first_loop }.string
    assert_match(/-{20}/, out)
  end

  def test_loop
    lair = MiGA::Lair.new(tmpdir, name: 'Ew', latency: 1, dry: true)
    out = capture_stderr { assert { !lair.daemon_loop } }.string
    assert_match(/Launching daemon: \S*project1/, out)
    assert_match(/Launching daemon: \S*project2/, out)
    assert_match(/Launching daemon: \S*sub\/project3/, out)
  end

  def test_daemon_launch
    lair = MiGA::Lair.new(tmpfile('sub'), latency: 1)
    p = MiGA::Project.load(File.join(lair.path, 'project3'))
    d = MiGA::Daemon.new(p)
    assert_not_predicate(d, :active?)
    assert_path_exist(d.daemon_home)

    declare_forks
    capture_stdout do
      FileUtils.touch(d.output_file) # <- To prevent test racing
      out = capture_stderr { lair.check_directories }.string
      assert_match(/Launching daemon: \S+project3/, out)
      assert_predicate(d, :active?)
    end

    out = capture_stderr { lair.terminate_daemons }.string
    assert_match(/Probing MiGA::Daemon/, out)
    assert_match(/Sending termination message/, out)
    sleep(2)
    assert_not_predicate(d, :active?)

    out = capture_stderr { assert { lair.daemon_loop } }.string
    assert_equal('', out)
  end

  def test_each_project
    lair = MiGA::Lair.new(tmpdir)
    y = []
    lair.each_project { |p| y << p }
    assert_equal(3, y.size)
    assert_instance_of(MiGA::Project, y[0])
    x = []
    lair.each_daemon { |d| x << d }
    assert_equal(4, x.size)
    assert_instance_of(MiGA::Lair, x[0])
    assert_instance_of(MiGA::Daemon, x[1])
  end
end
