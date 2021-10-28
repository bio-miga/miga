require 'test_helper'

class CommonTest < Test::Unit::TestCase
  include TestHelper

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
    hello = File.expand_path('Hello', tmpdir)
    world = File.expand_path('World', tmpdir)
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
  end

  def test_miga_name
    assert_equal('Xa sp. C', 'Xa_sp__C'.unmiga_name)
    assert_equal('X_______', 'X^*.!{}!'.miga_name)
    assert_equal('aB09', 'aB09'.miga_name)
    assert_predicate('R2D2', :miga_name?)
    assert_not_predicate('C3-PO', :miga_name?)
    assert_equal("123\n1\n", '1231'.wrap_width(3))
  end

  def test_advance
    m = MiGA::MiGA.new

    # Check advance when missing total
    o = capture_stderr { m.advance('x', 0) }.string
    assert_match(%r{\] x *\r}, o)

    # Initialize advance
    o = capture_stderr { m.advance('x', 0, 1001) }.string
    assert_match(%r{\] x 0\.0% \(0/1001\) *\r}, o)

    # Insufficient data for prediction
    sleep(1)
    o = capture_stderr { m.advance('x', 1, 1000) }.string
    assert_match(%r{\] x 0\.1% \(1/1000\) *\r}, o)

    # Predict time
    sleep(1)
    o = capture_stderr { m.advance('x', 2, 1000) }.string
    assert_match(%r{\] x 0\.2% \(2/1000\) 1\d\.\dm left *\r}, o)
  end

  def test_num_suffix
    m = MiGA::MiGA.new
    assert_equal('12', m.num_suffix(12))
    assert_equal('1.5K', m.num_suffix(1.5e3))
    assert_equal('1.0M', m.num_suffix(1024**2 + 1, true))
    assert_equal('1.1G', m.num_suffix(1024**3))
  end
end
