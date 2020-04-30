require 'test_helper'
require 'miga'
require 'miga/tax_index'

class TaxIndexTest < Test::Unit::TestCase
  include TestHelper

  def test_initialization
    ti = MiGA::TaxIndex.new
    assert_equal(:root, ti.root.rank)
  end

  def test_dataset
    initialize_miga_home
    d = dataset

    ti = MiGA::TaxIndex.new
    assert_empty(ti.datasets)
    ti << d
    assert_empty(ti.datasets, 'index should ignore datasets without tax')
    d.metadata[:tax] = MiGA::Taxonomy.new('k:Fantasia g:Unicornia')
    ti << d
    assert_equal(1, ti.datasets.size, 'index should have one dataset')
    assert_equal(1, ti.root.datasets_count)
  end

  def test_to_json
    js = JSON.parse(MiGA::TaxIndex.new.to_json)
    assert_include(js.keys, 'datasets')
    assert_equal(2, js.keys.size)
    assert_empty(js['datasets'])
  end

  def test_to_tab
    ti = MiGA::TaxIndex.new
    assert_equal("root:biota: 0\n", ti.to_tab)
  end
end
