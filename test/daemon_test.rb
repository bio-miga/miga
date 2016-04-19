require "test_helper"
require "miga/daemon"

class DaemonTest < Test::Unit::TestCase
  
  def setup
    $jruby_tests = !ENV["JRUBY_TESTS"].nil?
    $tmp = Dir.mktmpdir
    ENV["MIGA_HOME"] = $tmp
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_rc")
    File.open("#{ENV["MIGA_HOME"]}/.miga_daemon.json", "w") do |fh|
      fh.puts '{"maxjobs":1,"ppn":1,"latency":2,"varsep":" ","var":"%1$s=%2$s"}'
    end
    $p1 = MiGA::Project.new(File.expand_path("project1", $tmp))
    $d1 = MiGA::Daemon.new($p1)
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
  end

  def test_start
    $tmp2 = Dir.mktmpdir
    p = MiGA::Project.new(File.expand_path("start", $tmp))
    d = MiGA::Daemon.new(p)
    d.runopts(:latency, 0, true)
    assert_equal(0, d.latency)
    omit_if($jruby_tests, "JRuby doesn't implement fork.")
    $child = fork do
      capture_stdout do
	d.start
      end
    end
    sleep(1)
    assert(File.exist?(File.expand_path("daemon/MiGA:#{p.name}.pid",p.path)))
    out = capture_stdout { d.stop }
    assert(out.string =~ /MiGA:start: trying to stop process with pid \d+/)
    assert(!File.exist?(File.expand_path("daemon/MiGA:#{p.name}.pid",p.path)))
    assert(File.exist?(File.expand_path("daemon/MiGA:#{p.name}.output",p.path)))
  ensure
    Process.kill("KILL", $child) unless $child.nil?
  end

  def test_last_alive
    p = MiGA::Project.new(File.expand_path("last_alive", $tmp))
    d = MiGA::Daemon.new(p)
    assert_nil(d.last_alive)
    d.declare_alive
    assert(d.last_alive - DateTime.now < 1)
  end

  def test_options
    assert_respond_to($d1, :default_options)
    assert_equal(:normal, $d1.default_options[:dir_mode])
    assert_equal(2, $d1.runopts(:latency))
    assert_equal(1, $d1.maxjobs)
    assert_equal(2, $d1.latency)
    assert_equal(1, $d1.ppn)
    $d1.runopts(:alo, :ha)
    assert_equal(:ha, $d1.runopts(:alo))
    $d1.runopts(:maxjobs, "1")
    assert_equal(1, $d1.maxjobs)
    assert_raise do
      $d1.runopts(:latency, "!")
    end
  end

  def test_say
    out = capture_stdout do
      $d1.say "Olm"
    end
    assert(out.string =~ /^\[.*\] Olm/)
  end

end
