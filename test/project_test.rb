require "test_helper"
require "miga/project"

class ProjectTest < Test::Unit::TestCase
  
  def setup
    $tmp = Dir.mktmpdir
    ENV["MIGA_HOME"] = $tmp
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_rc")
    FileUtils.touch("#{ENV["MIGA_HOME"]}/.miga_daemon.json")
    $p1 = MiGA::Project.new(File.expand_path("project1", $tmp))
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV["MIGA_HOME"] = nil
  end
  
  def test_class_load
    assert_nil(MiGA::Project.load($tmp + "/O_o"))
    assert_equal(MiGA::Project, MiGA::Project.load($p1.path).class)
  end

  def test_create
    assert_equal("#{$tmp}/create", MiGA::Project.new("#{$tmp}/create").path)
    assert(Dir.exist?("#{$tmp}/create"))
    assert_raise do
      ENV["MIGA_HOME"] = $tmp + "/chez-moi"
      MiGA::Project.new($tmp + "/cuckoo")
    end
  ensure
    ENV["MIGA_HOME"] = $tmp
  end

  def test_load
    p = MiGA::Project.new($tmp + "/load")
    assert_equal(MiGA::Project, p.class)
    File.unlink p.metadata.path
    assert_raise do
      p.load
    end
  end

  def test_datasets
    p = $p1
    d = p.add_dataset("d1")
    assert_equal(MiGA::Dataset, d.class)
    assert_equal([d], p.datasets)
    assert_equal(["d1"], p.dataset_names)
    p.each_dataset{ |ds| assert_equal(d, ds) }
    dr = p.unlink_dataset("d1")
    assert_equal(d, dr)
    assert_equal([], p.datasets)
    assert_equal([], p.dataset_names)
  end

  def test_import_dataset
    p1 = $p1
    d1 = p1.add_dataset("d1")
    File.open("#{p1.path}/data/01.raw_reads/#{d1.name}.1.fastq",
      "w") { |f| f.puts ":-)" }
    File.open("#{p1.path}/data/01.raw_reads/#{d1.name}.done",
      "w") { |f| f.puts ":-)" }
    d1.next_preprocessing(true)
    p2 = MiGA::Project.new(File.expand_path("import_dataset", $tmp))
    assert(p2.datasets.empty?)
    assert_nil(p2.dataset("d1"))
    p2.import_dataset(d1)
    assert_equal(1, p2.datasets.size)
    assert_equal(MiGA::Dataset, p2.dataset("d1").class)
    assert_equal(1, p2.dataset("d1").results.size)
    assert(File.exist?(
      File.expand_path("data/01.raw_reads/#{d1.name}.1.fastq", p2.path)))
    assert(File.exist?(
      File.expand_path("metadata/#{d1.name}.json", p2.path)))
  end

end
