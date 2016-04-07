require "test_helper"

class GUITest < Test::Unit::TestCase
  
  def setup
    $gui_tests = !ENV["GUI_TESTS"].nil?
    require "miga/gui" if $gui_tests
  end

  def test_status
    omit_if(!$gui_tests, "GUI tested only in JRuby.")
    assert_respond_to(MiGA::GUI, :status)
  end

end
