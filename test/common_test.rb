require "test_helper"

class CommonTest < Test::Unit::TestCase
  
  def test_debug
    assert_respond_to(MiGA::MiGA, :DEBUG)
    assert_respond_to(MiGA::MiGA, :DEBUG_ON)
    assert_respond_to(MiGA::MiGA, :DEBUG_OFF)
    MiGA::MiGA.DEBUG_ON
    err = capture_stderr do
      MiGA::MiGA.DEBUG "Tralari"
    end
    assert_equal("Tralari\n", err.string)
    MiGA::MiGA.DEBUG_OFF
    err = capture_stderr do
      MiGA::MiGA.DEBUG "Tralara"
    end
    assert_equal("", err.string)
  ensure
    MiGA::MiGA.DEBUG_OFF
  end

  def test_debug_trace
    assert_respond_to(MiGA::MiGA, :DEBUG)
    assert_respond_to(MiGA::MiGA, :DEBUG_ON)
    assert_respond_to(MiGA::MiGA, :DEBUG_OFF)
    MiGA::MiGA.DEBUG_TRACE_ON
    err = capture_stderr do
      MiGA::MiGA.DEBUG "Dandadi"
    end
    assert(err.string =~ /Dandadi\n    .*block in test_debug_trace/)
    MiGA::MiGA.DEBUG_TRACE_OFF
    err = capture_stderr do
      MiGA::MiGA.DEBUG "Dandada"
    end
    assert_equal("Dandada\n", err.string)
  ensure
    MiGA::MiGA.DEBUG_TRACE_OFF
    MiGA::MiGA.DEBUG_OFF
  end

  def test_generic_transfer
    $tmp = Dir.mktmpdir
    hello = File.expand_path("Hello", $tmp)
    world = File.expand_path("World", $tmp)
    assert_respond_to(File, :generic_transfer)
    FileUtils.touch(hello)
    assert(File.exist?(hello))
    File.generic_transfer(hello, world, :symlink)
    assert_equal("link", File.ftype(world))
    assert(File.symlink?(world))
    File.unlink world
    File.generic_transfer(hello, world, :hardlink)
    assert_equal("file", File.ftype(world))
    File.open(hello, "w"){ |fh| fh.print "!" }
    File.open(world, "r"){ |fh| assert_equal("!", fh.gets) }
    File.unlink world
    File.generic_transfer(hello, world, :copy)
    assert_equal("file", File.ftype(world))
  ensure
    FileUtils.rm_rf $tmp
  end

end
