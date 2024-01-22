require 'test_helper'
require 'miga/project'

class ResultTest < Test::Unit::TestCase
  include TestHelper

  def setup
    initialize_miga_home
    to_touch = [
      ['02.trimmed_reads', "#{dataset.name}.1.clipped.fastq"],
      ['02.trimmed_reads', "#{dataset.name}.done"],
      ['10.clades', '01.find', 'miga-project.empty'],
      ['10.clades', '01.find', 'miga-project.done']
    ]
    to_touch.each do |path|
      FileUtils.touch(File.join(project.path, 'data', *path))
    end
  end

  def test_add_result
    r = dataset.add_result(:trimmed_reads)
    assert_instance_of(MiGA::Result, r)
    r = dataset.add_result(:asssembly)
    assert_nil(r)
    r = project.add_result(:clade_finding)
    assert_instance_of(MiGA::Result, r)
  end

  def test_unlink
    r = project.add_result(:clade_finding)
    path = r.path
    done = r.path(:done)
    data = r.file_path(:empty)
    assert(File.exist?(path))
    assert(File.exist?(done))
    assert(File.exist?(data))
    r.unlink
    assert(!File.exist?(path))
    assert(!File.exist?(done))
    assert(File.exist?(data))
  end

  def test_remove
    r = project.add_result(:clade_finding)
    data = r.file_path(:empty)
    assert(File.exist?(data))
    r.remove!
    assert(!File.exist?(data))
  end

  def test_result_source
    r = dataset.add_result(:trimmed_reads)
    assert_equal(dataset.name, r.source.name)
    assert_equal(:trimmed_reads, r.key)
    assert_equal('data/02.trimmed_reads', r.relative_dir)
    assert_equal('data/02.trimmed_reads/dataset0.json', r.relative_path)
    assert_equal(project.path, r.project.path)
    assert_equal(project.path, r.project_path)
    r = project.add_result(:clade_finding)
    assert_equal(project.path, r.source.path)
  end

  def test_dates
    r = dataset.add_result(:trimmed_reads)
    assert_nil(r.done_at)
    assert_nil(r.started_at)
    tf = File.join(
      project.path, 'data', '02.trimmed_reads', "#{dataset.name}.done"
    )
    File.open(tf, 'w') { |fh| fh.puts Time.new(1, 2, 3, 4, 5) }
    assert_equal(Time, r.done_at.class)
    assert_nil(r.running_time)
    tf = File.join(
      project.path, 'data', '02.trimmed_reads', "#{dataset.name}.start"
    )
    File.open(tf, 'w') { |fh| fh.puts Time.new(1, 2, 3, 4, 0) }
    r = dataset.add_result(:trimmed_reads)
    assert_equal(5.0, r.running_time)
  end

  def test_status
    d = dataset
    assert_equal(:ignore_empty, d.result_status(:trimmed_reads))
    d.add_result(:trimmed_reads)
    assert_equal(:-, d.result_status(:raw_reads))
    assert_equal(:complete, d.result_status(:trimmed_reads))
    assert_equal(:pending, d.result_status(:read_quality))
    assert_equal(:pending, d.result_status(:assembly))

    h = d.results_status
    assert(h.is_a? Hash)
    assert_equal(:-, h[:raw_reads])
    assert_equal(:complete, h[:trimmed_reads])
    assert_equal(:pending, h[:read_quality])

    # Test the "advance" interface from Project
    a = project.profile_datasets_advance
    assert(a.is_a? Array)
    assert_equal(1, a.size)
    assert(a[0].is_a? Array)
    assert_equal([0, 1, 2, 2], a[0][0..3])
  end

  def test_versions
    r = dataset.add_result(:trimmed_reads)
    assert_respond_to(r, :add_versions)
    assert_respond_to(r, :versions_md)
    assert_equal(MiGA::VERSION.join('.'), r.versions[:MiGA])
    assert_nil(r.versions[:GoodSoftware])

    r.add_versions('GoodSoftware' => '1.2.3')
    assert_equal('1.2.3', r.versions[:GoodSoftware])

    md = r.versions_md
    assert_equal('-', md[0])
    assert_equal(2, md.split("\n").size)
  end
end
