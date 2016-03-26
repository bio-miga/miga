require "test_helper"

class VersionTest < Test::Unit::TestCase
  
  def test_version
    assert_respond_to(MiGA::MiGA, :VERSION)
    assert_respond_to(MiGA::MiGA, :CITATION)
    assert_equal(MiGA::VERSION.first, MiGA::MiGA.VERSION)
  end
  
end
