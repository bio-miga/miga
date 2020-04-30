require 'test_helper'
require 'miga/common/with_daemon'

class WithDaemonTest < Test::Unit::TestCase
  include TestHelper

  class TestWithDaemon < MiGA::MiGA
    include MiGA::Common::WithDaemon
    extend MiGA::Common::WithDaemonClass

    attr :daemon_home

    def daemon_first_loop
      puts 'Hello, Underworld!'
    end

    def daemon_loop
      puts 'This is one loop'
      sleep(1)
      true
    end

    def daemon_name
      'TestDaemon'
    end

    def initialize(path)
      @daemon_home = path
    end

    def say(*o)
      puts(*o)
    end
  end

  class TestWithDaemon2 < TestWithDaemon
    def daemon_loop
      puts 'I am 2.0!'
      sleep(3)
      false
    end

    def terminate
      FileUtils.touch("#{alive_file}.x")
    end
  end

  def test_with_daemon
    d = TestWithDaemon.new(tmpdir)
    assert_respond_to(d, :pid_file)
    assert_respond_to(d.class, :daemon_home)
    assert_nil(d.loop_i)
  end

  def test_daemon_run
    d = TestWithDaemon2.new(tmpdir)
    capture_stdout { d.run }
    assert_path_not_exist(d.pid_file)
  end

  def test_daemmon_status
    d = TestWithDaemon.new(tmpdir)
    out = capture_stdout { d.status }.string
    assert_match(/Not running/, out)

    FileUtils.touch(d.output_file)
    capture_stdout { d.start }
    sleep(1)
    out = capture_stdout { d.status }.string
    assert_match(/Running with pid /, out)

    capture_stdout { d.stop }
    sleep(1)
    out = capture_stdout { d.status }.string
    assert_match(/Not running/, out)
  end

  def test_daemon_operations
    d = TestWithDaemon.new(tmpdir)
    FileUtils.touch(d.output_file)
    assert_not_predicate(d, :active?)

    declare_forks
    capture_stdout do
      pid = d.start
      assert_gt(pid, 0)
      sleep(1)
    end
    assert_predicate(d, :active?)

    capture_stdout { d.status }
    assert_predicate(d, :active?)

    assert_raise { d.declare_alive }

    assert_predicate(d, :active?)
    out = capture_stdout { d.stop }.string
    assert_match(/Sending termination message/, out)
    assert_nil(d.declare_alive_pid)
    assert_not_predicate(d, :active?)

    out = capture_stdout { d.stop }.string
    assert_match(/No running instances/, out)
  end

  def test_termination_file
    d = TestWithDaemon2.new(tmpdir)
    assert { !d.termination_file?(nil) }
    FileUtils.touch(d.terminate_file)
    err = capture_stdout do
      assert { d.termination_file?(nil) }
      sleep(1)
      assert_path_exist("#{d.alive_file}.x")
    end.string
    assert_match(/Found termination file/, err)
  end

  def test_process_alive
    d = TestWithDaemon2.new(tmpdir)
    assert { d.process_alive?(Process.pid) }
    assert { !d.process_alive?(1e9) }
  end

  def test_declare_alive_loop
    d = TestWithDaemon.new(tmpfile('nope'))
    assert_equal(:no_home, d.declare_alive_loop)

    d = TestWithDaemon.new(tmpdir)
    assert_equal(:no_process_alive, d.declare_alive_loop(1e9))

    declare_forks
    FileUtils.touch(d.terminate_file)
    child = fork { sleep(3) }
    capture_stdout do
      assert_equal(:termination_file, d.declare_alive_loop(child))
    end
  end

  def test_write_alive_file
    d = TestWithDaemon.new(tmpfile('nope'))
    assert_not_predicate(d, :active?)
    assert_raise { d.write_alive_file }
    assert_not_predicate(d, :active?)

    d = TestWithDaemon.new(tmpdir)
    assert_not_predicate(d, :active?)
    d.write_alive_file
    assert_predicate(d, :active?)
  end
end
