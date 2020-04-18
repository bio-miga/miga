require 'test_helper'
require 'miga/tax_dist'

class TaxDistTest < Test::Unit::TestCase

  def test_aai_path
    assert_path_exist(MiGA::TaxDist.aai_path(:intax))
    assert_path_exist(MiGA::TaxDist.aai_path(:novel))
    assert_path_exist(MiGA::TaxDist.aai_path(:intax, engine: :diamond))
    assert_path_exist(MiGA::TaxDist.aai_path(:novel, engine: :blast))
    assert_path_exist(MiGA::TaxDist.aai_path(:novel, engine: :'blast+'))
  end

  def test_aai_pvalues
    distant_intax = MiGA::TaxDist.aai_pvalues(35.0, :intax)
    assert_lt(distant_intax[:root], 0.05)
    assert_gt(distant_intax[:g], 0.05)
    assert_nil(distant_intax[:ns])

    close_intax = MiGA::TaxDist.aai_pvalues(99.0, :intax, engine: :blast)
    assert_lt(close_intax[:root], 0.05)
    assert_lt(close_intax[:s], 0.05)

    close_intax = MiGA::TaxDist.aai_pvalues(99.0, :intax, engine: :diamond)
    assert_lt(close_intax[:root], 0.05)
    assert_lt(close_intax[:s], 0.05)

    distant_novel = MiGA::TaxDist.aai_pvalues(35.0, :novel, engine: :diamond)
    assert_gt(distant_novel[:root], 0.05)
    assert_lt(distant_novel[:g], 0.05)
    assert_nil(distant_novel[:ns])

    close_novel = MiGA::TaxDist.aai_pvalues(99.0, :novel)
    assert_gt(close_novel[:root], 0.05)
    assert_gt(close_novel[:f], 0.05)

    assert_equal({}, MiGA::TaxDist.aai_pvalues(101.0, :intax))
  end

  def test_aai_taxtest
    distant_intax = MiGA::TaxDist.aai_taxtest(35.0, :intax, engine: :diamond)
    assert_equal(:root, distant_intax[:most_likely][0])
    assert_nil(distant_intax[:probably])
    assert_nil(distant_intax[:possibly_even])

    distant_intax = MiGA::TaxDist.aai_taxtest(35.0, :intax, engine: :blast)
    assert_equal(:root, distant_intax[:most_likely][0])
    assert_nil(distant_intax[:probably])
    assert_nil(distant_intax[:possibly_even])

    close_intax = MiGA::TaxDist.aai_taxtest(99.0, :intax, engine: :diamond)
    assert_equal(:s, close_intax[:probably][0])

    close_intax = MiGA::TaxDist.aai_taxtest(99.0, :intax, engine: :blast)
    assert_equal(:s, close_intax[:probably][0])
  end

end
