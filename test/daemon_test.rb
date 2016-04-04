require "test_helper"
require "miga/daemon"

class DaemonTest < Test::Unit::TestCase
  
  def setup
    $tmp = Dir.mktmpdir
    ENV["MIGA_HOME"] = $tmp
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_rc")
    File.open("#{ENV["MIGA_HOME"]}/.miga_daemon.json", "w") do |fh|
      fh.puts '{"maxjobs":1,"ppn":1,"latency":2}'
    end
    $p1 = MiGA::Project.new(File.expand_path("project1", $tmp))
    $d1 = MiGA::Daemon.new($p1)
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
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
