require "test_helper"
require "miga/project"
require "miga/remote_dataset"

class RemoteDatasetTest < Test::Unit::TestCase
  
  def setup
    $tmp = Dir.mktmpdir
    ENV["MIGA_HOME"] = $tmp
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_rc")
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_daemon.json")
    $p1 = MiGA::Project.new(File.expand_path("project1", $tmp))
    $remote_tests = !ENV["REMOTE_TESTS"].nil?
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
  end
  
  def test_class_universe
    assert_respond_to(MiGA::RemoteDataset, :UNIVERSE)
    assert(MiGA::RemoteDataset.UNIVERSE.keys.include? :ebi)
  end

  def test_bad_remote_dataset
    assert_raise { MiGA::RemoteDataset.new('ids', :embl, :marvel) }
    assert_raise { MiGA::RemoteDataset.new('ids', :google, :ebi) }
  end

  def test_rest
    hiv2 = 'M30502.1'
    {embl: :ebi, nuccore: :ncbi}.each do |db, universe|
      rd = MiGA::RemoteDataset.new(hiv2, db, universe)
      assert_equal([hiv2], rd.ids)
      omit_if(!$remote_tests, 'Remote access is error-prone.')
      tx = rd.get_ncbi_taxonomy
      msg = "Failed on #{universe}:#{db}"
      assert_equal(MiGA::Taxonomy, tx.class, msg)
      assert_equal('Lentivirus', tx[:g], msg)
      assert_equal('ns:ncbi o:Ortervirales f:Retroviridae ' \
        'g:Lentivirus s:Human_immunodeficiency_virus_2', tx.to_s, msg)
      assert_equal('ns:ncbi d: k: p: c: o:Ortervirales f:Retroviridae ' \
        'g:Lentivirus s:Human_immunodeficiency_virus_2 ssp: str: ds:',
        tx.to_s(true), msg)
      assert_equal('ncbi', tx.namespace, msg)
    end
  end

  def test_net_ftp
    cjac = 'ftp://ftp.ebi.ac.uk/pub/databases/ena/tsa/public/ga/GAPJ01.fasta.gz'
    n = 'Cjac_L14'
    rd = MiGA::RemoteDataset.new(cjac, :assembly_gz, :web)
    assert_equal([cjac], rd.ids)
    omit_if(!$remote_tests, 'Remote access is error-prone.')
    p = $p1
    assert_nil(p.dataset(n))
    rd.save_to(p, n)
    p.add_dataset(n)
    assert_equal(MiGA::Dataset, p.dataset(n).class)
    assert_equal(MiGA::Result, p.dataset(n).result(:assembly).class)
  end

  # This test is too expensive (too much time to run it!)
  #def test_net_timeout
  #  omit_if(!$remote_tests, "Remote access is error-prone.")
  #  bad = "ftp://example.com/miga"
  #  rd = MiGA::RemoteDataset.new(bad, :assembly, :web)
  #  assert_raise(Net::ReadTimeout) { rd.save_to($p1, "bad") }
  #end

end
