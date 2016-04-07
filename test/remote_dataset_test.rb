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
    $remote_tests = ENV["NO_REMOTE_TESTS"].nil?
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
    assert_raise { MiGA::RemoteDataset.new("ids", :embl, :marvel) }
    assert_raise { MiGA::RemoteDataset.new("ids", :google, :ebi) }
  end

  def test_ebi
    hiv2 = "M30502.1"
    rd = MiGA::RemoteDataset.new(hiv2, :embl, :ebi)
    assert_equal([hiv2], rd.ids)
    omit_if(!$remote_tests, "Remote access is error-prone.")
    tx = rd.get_ncbi_taxonomy
    assert_equal(MiGA::Taxonomy, tx.class)
    assert_equal("Lentivirus", tx[:g])
  end

end
