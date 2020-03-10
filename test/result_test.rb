require 'test_helper'
require 'miga/project'

class ResultTest < Test::Unit::TestCase

  def setup
    $tmp = Dir.mktmpdir
    ENV['MIGA_HOME'] = $tmp
    FileUtils.touch(File.expand_path('.miga_rc', ENV['MIGA_HOME']))
    FileUtils.touch(File.expand_path('.miga_daemon.json', ENV['MIGA_HOME']))
    $p1 = MiGA::Project.new(File.expand_path('project1', $tmp))
    $d1 = $p1.add_dataset('dataset1')
    FileUtils.touch(File.expand_path(
      "data/02.trimmed_reads/#{$d1.name}.1.clipped.fastq", $p1.path))
    FileUtils.touch(File.expand_path(
      "data/02.trimmed_reads/#{$d1.name}.done", $p1.path))
    FileUtils.touch(File.expand_path(
      'data/10.clades/01.find/miga-project.empty', $p1.path))
    FileUtils.touch(File.expand_path(
      'data/10.clades/01.find/miga-project.done', $p1.path))
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV['MIGA_HOME'] = nil
  end

  def test_add_result
    r = $d1.add_result(:trimmed_reads)
    assert_equal(MiGA::Result, r.class)
    r = $d1.add_result(:asssembly)
    assert_nil(r)
    r = $p1.add_result(:clade_finding)
    assert_equal(MiGA::Result, r.class)
  end

  def test_result_source
    r = $d1.add_result(:trimmed_reads)
    assert_equal($d1.name, r.source.name)
    assert_equal(:trimmed_reads, r.key)
    assert_equal('data/02.trimmed_reads', r.relative_dir)
    assert_equal('data/02.trimmed_reads/dataset1.json', r.relative_path)
    assert_equal($p1.path, r.project.path)
    assert_equal($p1.path, r.project_path)
    r = $p1.add_result(:clade_finding)
    assert_equal($p1.path, r.source.path)
  end

end
