require "test_helper"
require "miga/taxonomy"

class TaxonomyTest < Test::Unit::TestCase
  
  def test_ranks
    assert_respond_to(MiGA::Taxonomy, :KNOWN_RANKS)
    assert(MiGA::Taxonomy.KNOWN_RANKS.include? :s)
    assert_nil(MiGA::Taxonomy.normalize_rank "No Rank")
    assert_nil(MiGA::Taxonomy.normalize_rank "Captain")
    assert_equal(:f, MiGA::Taxonomy.normalize_rank(:Family))
  end

  def test_json
    js = '{"json_class":"MiGA::Taxonomy",' +
      '"str":"k:Fantasia f:Dragonaceae s:Dragonia_azura"}'
    tx = JSON.parse(js, {:symbolize_names=>false, :create_additions=>true})
    assert_equal(MiGA::Taxonomy, tx.class)
    assert_equal("Dragonaceae", tx[:f])
    assert_equal(js, tx.to_json)
  end

  def test_append
    tx = MiGA::Taxonomy.new ""
    assert_equal("", "#{tx}")
    tx << ["domain:Public","family:GNU"]
    assert_equal("GNU", tx[:f])
    tx << "class:ShareAlike"
    assert_equal("ShareAlike", tx[:c])
    tx << { :genus => "v3" }
    assert_equal("v3", tx[:g])
    tx << "s:v3_0"
    assert(tx.is_in? MiGA::Taxonomy.new("species:v3_0"))
    assert_raise(RuntimeError) { tx << 123 }
  end

  def test_init_methods
    tx = MiGA::Taxonomy.new({:k=>"Mascot", :c=>"Cereal", :s=>"Melvin"})
    assert_equal("k:Mascot c:Cereal s:Melvin", tx.to_s)
    tx = MiGA::Taxonomy.new("Mascot College Buzz", "k c s")
    assert_equal("k:Mascot c:College s:Buzz", tx.to_s)
    assert_raise do
      tx = MiGA::Taxonomy.new("Mascot State Georgia Peach", "k c s")
    end
  end

end
