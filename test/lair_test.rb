require 'test_helper'
require 'miga/lair'

class LairTest < Test::Unit::TestCase

  def setup
    $jruby_tests = !ENV['JRUBY_TESTS'].nil?
    $tmp = Dir.mktmpdir
    ENV['MIGA_HOME'] = $tmp
    FileUtils.touch(File.expand_path('.miga_rc', ENV['MIGA_HOME']))
    daemon_json = File.expand_path('.miga_daemon.json', ENV['MIGA_HOME'])
    File.open(daemon_json, 'w') do |fh|
      fh.puts '{"maxjobs":1,"ppn":1,"latency":1,"varsep":" ",
        "var":"{{key}}={{value}}","cmd":"echo {{task_name}} >/dev/null",
        "alive":"echo 1 # {{pid}}","type":"bash","format_version":1}'
    end
    Dir.mkdir(File.join($tmp, 'sub'))
    $p1 = MiGA::Project.new(File.join($tmp, 'project1'))
    $p2 = MiGA::Project.new(File.join($tmp, 'project2'))
    $p3 = MiGA::Project.new(File.join($tmp, 'sub/project3'))
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV['MIGA_HOME'] = nil
  end
  
  def test_lair_init
    path = $tmp
    lair = MiGA::Lair.new(path, name: 'Alt-X')
    assert_equal(MiGA::Lair, lair.class)
    assert_equal(path, lair.path)
    assert_equal(path, lair.daemon_home)
    assert_equal('MiGA:Alt-X', lair.daemon_name)
    assert_equal(lair.daemon_home, MiGA::Lair.daemon_home(lair.daemon_home))
  end

  def test_in_loop
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
    lair = MiGA::Lair.new($tmp, name: 'Oh')
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
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
    lair = MiGA::Lair.new($tmp, name: 'Ew')
    out = capture_stderr { lair.daemon_first_loop }.string
    assert_match(/-{20}/, out)
  end

  def test_loop
    lair = MiGA::Lair.new($tmp, name: 'Ew', latency: 1, dry: true)
    out = capture_stderr { assert { !lair.daemon_loop } }.string
    assert_match(/Launching daemon: \S*project1/, out)
    assert_match(/Launching daemon: \S*project2/, out)
    assert_match(/Launching daemon: \S*sub\/project3/, out)
  end

  def test_daemon_launch
    lair = MiGA::Lair.new(File.join($tmp, 'sub'), latency: 1)
    p = MiGA::Project.load(File.join(lair.path, 'project3'))
    d = MiGA::Daemon.new(p)
    assert_not_predicate(d, :active?)
    assert_path_exist(d.daemon_home)

    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
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
end
