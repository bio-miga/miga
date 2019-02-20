require "test_helper"
require "miga/daemon"

class DaemonTest < Test::Unit::TestCase
  
  def setup
    $jruby_tests = !ENV["JRUBY_TESTS"].nil?
    $tmp = Dir.mktmpdir
    ENV["MIGA_HOME"] = $tmp
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_rc")
    File.open("#{ENV["MIGA_HOME"]}/.miga_daemon.json", "w") do |fh|
      fh.puts '{"maxjobs":1,"ppn":1,"latency":2,"varsep":" ","var":"%s=%s",
        "cmd":"%5$s","alive":"echo 1 # %s","type":"bash"}'
    end
    $p1 = MiGA::Project.new(File.expand_path("project1", $tmp))
    $d1 = MiGA::Daemon.new($p1)
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
  end

  def test_check_project
  
  end

  def test_check_datasets
    p = $p1
    d = $d1
    d.runopts(:maxjobs, 0, true)
    assert(d.jobs_to_run.empty?)
    ds = p.add_dataset("ds1")
    d.check_datasets
    assert(d.jobs_to_run.empty?)
    FileUtils.cp(File.expand_path("daemon/daemon.json", p.path),
      File.expand_path("data/01.raw_reads/ds1.1.fastq", p.path))
    FileUtils.cp(File.expand_path("daemon/daemon.json", p.path),
      File.expand_path("data/01.raw_reads/ds1.done", p.path))
    out = capture_stdout do
      d.check_datasets
    end
    assert(out.string =~ /Queueing #{ds.name}:trimmed_reads/)
    assert_equal(1, d.jobs_to_run.size)
    assert_equal("project1:trimmed_reads:ds1", d.jobs_to_run.first[:cmd])
    assert_equal(d.jobs_to_run.first, d.get_job(:trimmed_reads, ds))
  end

  def test_in_loop
    p = $p1
    d = $d1
    d.runopts(:latency, 0, true)
    assert_equal(-1, d.loop_i)
    assert_nil(d.last_alive)
    out = capture_stdout do
      d.in_loop
    end
    assert_equal(Time, d.last_alive.class)
    assert(out.string =~ /-{20}\n.*MiGA:#{p.name} launched/)
    2.times{ d.in_loop }
    assert_equal(3, d.loop_i)
    out = capture_stdout do
      d.in_loop
    end
    assert(out.string =~ /Housekeeping for sanity/)
    assert_equal(0, d.loop_i)
  end

  def test_start
    p = $p1
    d = $d1
    d.runopts(:latency, 0, true)
    assert_equal(0, d.latency)
    omit_if($jruby_tests, "JRuby doesn't implement fork.")
    $child = fork { d.start(["--shush"]) }
    sleep(3)
    dpath = File.expand_path("daemon/MiGA:#{p.name}",p.path)
    assert(File.exist?("#{dpath}.pid"))
    out = capture_stdout { d.stop }
    assert(out.string =~ /MiGA:#{p.name}: trying to stop process with pid \d+/)
    assert(!File.exist?("#{dpath}.pid"))
    assert(File.exist?("#{dpath}.output"))
    File.open("#{dpath}.output", "r") do |fh|
      l = fh.each_line.to_a
      assert(l[0] =~ /-{20}\n/)
      assert(l[1] =~ /MiGA:#{p.name} launched/)
      assert(l[2] =~ /-{20}\n/)
      assert(l[3] =~ /Housekeeping for sanity\n/)
    end
  ensure
    Process.kill("KILL", $child) unless $child.nil?
  end

  def test_last_alive
    p = MiGA::Project.new(File.expand_path("last_alive", $tmp))
    d = MiGA::Daemon.new(p)
    assert_nil(d.last_alive)
    d.declare_alive
    assert(d.last_alive - Time.now < 1)
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
    assert_equal("bash", $d1.runopts(:type))
    assert_equal("kill -9 '%s'", $d1.runopts(:kill))
    $d1.runopts(:type, "qsub")
    assert_equal("qdel '%s'", $d1.runopts(:kill))
    $d1.runopts(:type, "msub")
    assert_equal("canceljob '%s'", $d1.runopts(:kill))
  end

  def test_say
    out = capture_stdout do
      $d1.say "Olm"
    end
    assert(out.string =~ /^\[.*\] Olm/)
  end

  def test_terminate
    d = $d1
    d.declare_alive
    assert_not_nil(d.last_alive)
    out = capture_stdout do
      d.terminate
    end
    assert(out.string =~ /Terminating daemon/)
    assert_nil(d.last_alive)
  end

end
