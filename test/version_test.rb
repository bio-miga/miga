require "test_helper.rb"

class VersionTest < Test::Unit::TestCase
  
  def test_version
    assert_respond_to(MiGA::MiGA, :VERSION)
    assert_respond_to(MiGA::MiGA, :CITATION)
  end
  
end
