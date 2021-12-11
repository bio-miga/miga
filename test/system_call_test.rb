require 'test_helper'

class SystemCallTest < Test::Unit::TestCase
  include TestHelper

  def test_run_cmd_opts
    assert_equal(true, MiGA::MiGA.run_cmd_opts[:raise])
    assert_equal(:status, MiGA::MiGA.run_cmd_opts[:return])
    assert_equal(:pid, MiGA::MiGA.run_cmd_opts(return: :pid)[:return])
    assert_nil(MiGA::MiGA.run_cmd_opts[:stdout])
  end

  def test_run_cmd_redirection
    f1 = tmpfile('f1')
    MiGA::MiGA.run_cmd('echo 1', stdout: f1)
    assert_equal("1\n", File.read(f1))

    MiGA::MiGA.run_cmd('echo 2 >&2', stderr: f1)
    assert_equal("2\n", File.read(f1))

    f2 = tmpfile('with spaces')
    MiGA::MiGA.run_cmd('echo 3', stdout: f2)
    assert_equal("3\n", File.read(f2))

    MiGA::MiGA.run_cmd(['echo', 4], stdout: f2)
    assert_equal("4\n", File.read(f2))
  end

  def test_run_cmd_return
    o = MiGA::MiGA.run_cmd('echo 1', stdout: '/dev/null')
    assert(o.is_a? Process::Status)
    assert(o.success?)

    o = MiGA::MiGA.run_cmd('echo 1', stdout: '/dev/null', return: :pid)
    assert(o.is_a? Integer)

    o = MiGA::MiGA.run_cmd('echo 1', stdout: '/dev/null', return: :error)
    assert_nil(o)
  end

  def test_run_cmd_raise
    assert_raise(MiGA::SystemCallError) { MiGA::MiGA.run_cmd('echoes!!!') }

    o = MiGA::MiGA.run_cmd('echoes!!!', raise: false, return: :status)
    assert_not(o.success?)

    o = MiGA::MiGA.run_cmd('echoes!!!', raise: false, return: :error)
    assert(o.is_a? Errno::ENOENT)
  end
end
