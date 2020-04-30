require 'test_helper'
require 'miga/project'

class ResultTest < Test::Unit::TestCase
  include TestHelper

  def setup
    initialize_miga_home
    FileUtils.touch(
      File.join(
        project.path, 'data', '02.trimmed_reads',
        "#{dataset.name}.1.clipped.fastq"
      )
    )
    FileUtils.touch(
      File.join(
        project.path, 'data', '02.trimmed_reads', "#{dataset.name}.done"
      )
    )
    FileUtils.touch(
      File.join(
        project.path, 'data', '10.clades', '01.find', 'miga-project.empty'
      )
    )
    FileUtils.touch(
      File.join(
        project.path, 'data', '10.clades', '01.find', 'miga-project.done'
      )
    )
  end

  def test_add_result
    r = dataset.add_result(:trimmed_reads)
    assert_instance_of(MiGA::Result, r)
    r = dataset.add_result(:asssembly)
    assert_nil(r)
    r = project.add_result(:clade_finding)
    assert_instance_of(MiGA::Result, r)
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
end
