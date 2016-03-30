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

  def teardown
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
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

  def test_save
    d2 = $p1.add_dataset("ds_save")
    assert_respond_to(d2, :save)
    d2.save
    assert(!d2.is_multi?)
    assert(!d2.is_nonmulti?)
    assert_nil(d2.metadata[:type])
    d2.metadata[:tax] = {:ns=>"COMMUNITY"}
    d2.save
    assert_equal(:metagenome, d2.metadata[:type])
    assert(d2.is_multi?)
    assert(!d2.is_nonmulti?)
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

  def test_add_result
    d2 = $p1.add_dataset("ds_add_result")
    assert_nil(d2.add_result(:koop))
    assert_nil(d2.add_result(:raw_reads))
    FileUtils.touch(
      File.expand_path("data/01.raw_reads/#{d2.name}.1.fastq",$p1.path))
    assert_nil(d2.add_result(:raw_reads))
    FileUtils.touch(
      File.expand_path("data/01.raw_reads/#{d2.name}.done",$p1.path))
    assert_equal(MiGA::Result, d2.add_result(:raw_reads).class)
  end

  def test_preprocessing
    d2 = $p1.add_dataset("ds_preprocessing")
    assert_nil(d2.first_preprocessing)
    assert_nil(d2.next_preprocessing)
    assert(! d2.done_preprocessing?)
    FileUtils.touch(
      File.expand_path("data/01.raw_reads/#{d2.name}.1.fastq",$p1.path))
    FileUtils.touch(
      File.expand_path("data/01.raw_reads/#{d2.name}.done",$p1.path))
    assert_equal(:raw_reads, d2.first_preprocessing)
    assert_equal(:trimmed_reads, d2.next_preprocessing)
    assert(! d2.done_preprocessing?)
    assert(d2.ignore_task?(:mytaxa))
    assert(d2.ignore_task?(:distances))
    d2.metadata[:type] = :metagenome
    assert(! d2.ignore_task?(:mytaxa))
    assert(d2.ignore_task?(:distances))
    d2.metadata[:type] = :genome
    assert(d2.ignore_task?(:mytaxa))
    assert(! d2.ignore_task?(:distances))
  end

end
