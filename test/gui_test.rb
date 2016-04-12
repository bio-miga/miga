require "test_helper"

class GUITest < Test::Unit::TestCase
  
  def setup
    $gui_tests = !ENV["GUI_TESTS"].nil?
    if $gui_tests
      require "miga/gui"
      $app = MiGA::GUI.init
    end
  end

  def test_status
    omit_if(!$gui_tests, "GUI tested only in JRuby.")
    assert_respond_to(MiGA::GUI, :status)
    assert_equal("MiGA is ready to go!", MiGA::GUI.status)
    assert_equal(MiGA::GUI, $app.class)
  end

end
