require 'test_helper'

class CommonTest < Test::Unit::TestCase

  def setup
    #$jruby_tests = !ENV["JRUBY_TESTS"].nil?
  end

  def test_debug
    assert_respond_to(MiGA::MiGA, :DEBUG)
    assert_respond_to(MiGA::MiGA, :DEBUG_ON)
    assert_respond_to(MiGA::MiGA, :DEBUG_OFF)
    MiGA::MiGA.DEBUG_ON
    err = capture_stderr do
      MiGA::MiGA.DEBUG 'Tralari'
    end
    assert_equal("Tralari\n", err.string)
    MiGA::MiGA.DEBUG_OFF
    err = capture_stderr do
      MiGA::MiGA.DEBUG 'Tralara'
    end
    assert_equal('', err.string)
  ensure
    MiGA::MiGA.DEBUG_OFF
  end

  def test_debug_trace
    assert_respond_to(MiGA::MiGA, :DEBUG)
    assert_respond_to(MiGA::MiGA, :DEBUG_ON)
    assert_respond_to(MiGA::MiGA, :DEBUG_OFF)
    #omit_if($jruby_tests, "JRuby doesn't like interceptions.")
    MiGA::MiGA.DEBUG_TRACE_ON
    err = capture_stderr do
      MiGA::MiGA.DEBUG 'Dandadi'
    end
    assert_match(/Dandadi\n    .*block in test_debug_trace/, err.string)
    MiGA::MiGA.DEBUG_TRACE_OFF
    err = capture_stderr do
      MiGA::MiGA.DEBUG 'Dandada'
    end
    assert_equal("Dandada\n", err.string)
  ensure
    MiGA::MiGA.DEBUG_TRACE_OFF
    MiGA::MiGA.DEBUG_OFF
  end

  def test_generic_transfer
    $tmp = Dir.mktmpdir
    hello = File.expand_path('Hello', $tmp)
    world = File.expand_path('World', $tmp)
    assert_respond_to(File, :generic_transfer)
    FileUtils.touch(hello)
    File.generic_transfer(hello, world, :symlink)
    assert_equal('link', File.ftype(world), 'World should be a link.')
    File.generic_transfer(hello, world, :copy)
    assert_equal('link', File.ftype(world), 'World should still be a link.')
    File.unlink world
    File.generic_transfer(hello, world, :hardlink)
    assert_equal('file', File.ftype(world), 'A hardlink should be a file.')
    File.open(hello, 'w') { |fh| fh.print '!' }
    File.open(world, 'r') { |fh| assert_equal('!', fh.gets) }
    File.unlink world
    File.generic_transfer(hello, world, :copy)
    assert_equal('file', File.ftype(world), 'A copy should be a file.')
    File.unlink world
    assert_raise do
      File.generic_transfer(hello, world, :monkey)
    end
    assert_path_not_exist(world, 'A monkey shouldn\'t create files.')
  ensure
    FileUtils.rm_rf $tmp
  end

  def test_miga_name
    assert_equal('Xa sp. C', 'Xa_sp__C'.unmiga_name)
    assert_equal('X_______', 'X^*.!{}!'.miga_name)
    assert_equal('aB09', 'aB09'.miga_name)
    assert_predicate('R2D2', :miga_name?)
    assert_not_predicate('C3-PO', :miga_name?)
    assert_equal("123\n1\n", '1231'.wrap_width(3))
  end

end
