require "test_helper"
require "miga/dataset"

class DatasetTest < Test::Unit::TestCase
  
  def test_known_types
    assert_respond_to(MiGA::Dataset, :KNOWN_TYPES)
    assert(MiGA::Dataset.KNOWN_TYPES.has_key?(:genome))
  end
  
end
