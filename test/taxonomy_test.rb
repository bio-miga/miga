require 'test_helper'
require 'miga/taxonomy'

class TaxonomyTest < Test::Unit::TestCase
  def test_ranks
    assert_respond_to(MiGA::Taxonomy, :KNOWN_RANKS)
    assert_include(MiGA::Taxonomy.KNOWN_RANKS, :s)
    assert_nil(MiGA::Taxonomy.normalize_rank 'No Rank')
    assert_nil(MiGA::Taxonomy.normalize_rank 'Captain')
    assert_equal(:f, MiGA::Taxonomy.normalize_rank(:Family))
  end

  def test_json
    txt = 'k:Fantasia f:Dragonaceae s:Dragonia_azura'
    js = '{"json_class":"MiGA::Taxonomy","str":"' + txt + '"}'
    tx = JSON.parse(js, { symbolize_names: false, create_additions: true })
    assert_equal(MiGA::Taxonomy, tx.class)
    assert_equal('Dragonaceae', tx[:f])
    assert_equal(js, tx.to_json)
  end

  def test_namespace
    txt = 'ns:Irrealis k:Fantasia f:Dragonaceae s:Dragonia_azura'
    tx = MiGA::Taxonomy.new(txt)
    assert_equal(txt, tx.to_s)
    assert_equal(
      [[:k, 'Fantasia'], [:f, 'Dragonaceae'], [:s, 'Dragonia azura']],
      tx.sorted_ranks
    )
    assert_equal('Irrealis', tx.namespace)
  end

  def test_append
    tx = MiGA::Taxonomy.new ''
    assert_equal('', "#{tx}")
    tx << ['domain:Public', 'family:GNU']
    assert_equal('GNU', tx[:f])
    tx << 'class:ShareAlike'
    assert_equal('ShareAlike', tx[:c])
    tx << { genus: 'v3' }
    assert_equal('v3', tx[:g])
    tx << 's:v3_0'
    assert { tx.in? MiGA::Taxonomy.new('species:v3_0') }
    assert_raise(RuntimeError) { tx << 123 }
  end

  def test_init_methods
    tx = MiGA::Taxonomy.new({ k: 'Mascot', c: 'Cereal', s: 'Melvin' })
    assert_equal('k:Mascot c:Cereal s:Melvin', tx.to_s)
    tx = MiGA::Taxonomy.new('Mascot College Buzz', 'k c s')
    assert_equal('k:Mascot c:College s:Buzz', tx.to_s)
    assert_raise do
      tx = MiGA::Taxonomy.new('Mascot State Georgia Peach', 'k c s')
    end
  end

  def test_rank_order
    tx = MiGA::Taxonomy.new({ k: 'Mascot', s: 'Melvin', c: 'Cereal' })
    assert_equal([:d, nil], tx.highest(true))
    assert_equal([:k, 'Mascot'], tx.highest)
    assert_equal([:ds, nil], tx.lowest(true))
    assert_equal([:s, 'Melvin'], tx.lowest)
  end

  def test_alternative
    tx = MiGA::Taxonomy.new('ns:a s:Arnie', nil,
                            ['ns:b s:Bernie', 'ns:c s:Cornie', 's:Darnie'])
    # Fields
    assert_equal('ns:a s:Arnie', tx.to_s)
    assert_equal([[:s, 'Arnie']], tx.sorted_ranks)
    assert_equal('ns:a s:Arnie', tx.alternative(0).to_s)
    assert_equal('ns:b s:Bernie', tx.alternative(1).to_s)
    assert_equal('ns:c s:Cornie', tx.alternative(:c).to_s)
    assert_equal('s:Darnie', tx.alternative('').to_s)
    assert_nil(tx.alternative(:x))
    assert_equal(3, tx.alternative.size)
    # JSON
    js = tx.to_json
    tx_js = JSON.parse(js, { symbolize_names: false, create_additions: true })
    assert_equal(tx.to_s, tx_js.to_s)
    assert_equal(tx.alternative(2).to_s, tx_js.alternative(2).to_s)
    assert_equal(tx.alternative.size, tx_js.alternative.size)
    # Add
    tx.add_alternative(tx.alternative(3))
    assert_equal(4, tx.alternative.size)
    tx.add_alternative(tx.alternative(2))
    assert_equal(4, tx.alternative.size)
    # Delete
    alt = tx.delete_alternative
    assert_equal(4, alt.size)
    assert_empty(tx.alternative)
  end

  def test_reset
    tx = MiGA::Taxonomy.new(
      'ns:Letters d:Latin s:A', nil,
      ['ns:Words d:English s:A', 'ns:Music d:Tone s:A']
    )
    assert_equal('Latin', tx.domain)

    # Reset
    assert_equal(2, tx.alternative.size)
    assert_equal('Letters', tx.namespace)
    tx.reset('g:A')
    assert_equal(2, tx.alternative.size)
    assert_nil(tx.namespace)
    tx.reset('ns:Letters d:Latin s:A')
    assert_equal('Letters', tx.namespace)

    # Change of alternative
    assert_equal('ns:Words d:English s:A', tx.alternative('Words').to_s)
    tx.add_alternative(MiGA::Taxonomy.new('ns:Words d:Spanish s:A'))
    assert_equal('ns:Words d:Spanish s:A', tx.alternative('Words').to_s)

    # Change of main
    assert_equal('ns:Letters d:Latin s:A', tx.to_s)
    tx.add_alternative(MiGA::Taxonomy.new('ns:Letters d:Unicode s:A'))
    assert_equal('ns:Letters d:Unicode s:A', tx.to_s)
  end
end
