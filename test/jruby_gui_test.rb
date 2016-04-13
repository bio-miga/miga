require "test_helper"
require "miga/gui"

class GUITest < Test::Unit::TestCase
  
  def setup
    $app = MiGA::GUI.new
  end

  def test_status
    assert_respond_to(MiGA::GUI, :status)
    assert_equal("Initializing MiGA...", MiGA::GUI.status)
    assert_equal(MiGA::GUI, $app.class)
    MiGA::GUI.status = "Well well well..."
    assert_equal("Well well well...", MiGA::GUI.status)
    MiGA::GUI.reset_status
    assert_equal("MiGA is ready to go!", MiGA::GUI.status)
  end

end
