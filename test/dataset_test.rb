require "test_helper"
require "miga/project"

class DatasetTest < Test::Unit::TestCase
  
  def setup
    $tmp = Dir.mktmpdir
    ENV["MIGA_HOME"] = $tmp
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_rc")
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_daemon.json")
    $p1 = MiGA::Project.new(File.expand_path("project1", $tmp))
    $d1 = $p1.add_dataset("dataset1")
  end

  def test_known_types
    assert_respond_to(MiGA::Dataset, :KNOWN_TYPES)
    assert(MiGA::Dataset.KNOWN_TYPES.has_key?(:genome))
  end

  def test_exist
    assert_respond_to(MiGA::Dataset, :exist?)
    assert(MiGA::Dataset.exist?($p1, "dataset1"))
    assert(! MiGA::Dataset.exist?($p1, "Nope"))
  end

  def test_info_fields
    assert_respond_to(MiGA::Dataset, :INFO_FIELDS)
    assert(MiGA::Dataset.INFO_FIELDS.include?("name"))
  end

  def test_initialize
    assert_raise do
      MiGA::Dataset.new($p1, "dataset-1")
    end
    assert_equal($p1, $d1.project)
    assert_equal("dataset1", $d1.name)
    assert($d1.is_ref?)
    assert_equal(MiGA::Metadata, $d1.metadata.class)
  end

  def test_remove
    d2 = $p1.add_dataset("ds_remove")
    assert(File.exist?(d2.metadata.path))
    d2.remove!
    assert(! File.exist?(d2.metadata.path))
  end

  def test_info
    assert_equal($d1.name, $d1.info.first)
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
  end
  
end
