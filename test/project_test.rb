require 'test_helper'
require 'miga/project'

class ProjectTest < Test::Unit::TestCase
  include TestHelper

  def setup
    initialize_miga_home
  end

  def create_result_files(project, res, exts)
    d = MiGA::Project.RESULT_DIRS[res]
    (['.done'] + exts).each do |x|
      assert_nil(
        project.add_result(res),
        "Premature registration of result #{res} at extension #{x}"
      )
      FileUtils.touch(File.join(project.path, 'data', d, "miga-project#{x}"))
    end
  end

  def test_class_load
    assert_nil(MiGA::Project.load(tmpfile('O_o')))
    assert_instance_of(MiGA::Project, MiGA::Project.load(project.path))
  end

  def test_create
    assert_equal(tmpfile('create'), project('create').path)
    assert_path_exist(tmpfile('create'))
    assert_raise do
      ENV['MIGA_HOME'] = tmpfile('chez-moi')
      project('cuckoo')
    end
  end

  def test_load
    p = project('load')
    assert_equal(MiGA::Project, p.class)
    File.unlink p.metadata.path
    assert_raise do
      p.load
    end
  end

  def test_datasets
    p = project
    d = dataset(0, 'd1')
    assert_equal(MiGA::Dataset, d.class)
    assert_equal([d], p.datasets)
    assert_equal(['d1'], p.dataset_names)
    p.each_dataset { |ds| assert_equal(d, ds) }
    dr = p.unlink_dataset('d1')
    assert_equal(d, dr)
    assert_equal([], p.datasets)
    assert_equal([], p.dataset_names)
  end

  def test_import_dataset
    p1 = project
    d = p1.add_dataset('d1')
    File.open(
      File.join(p1.path, 'data', '01.raw_reads', "#{d.name}.1.fastq"), 'w'
    ) { |f| f.puts ':-)' }
    File.open(
      File.join(p1.path, 'data', '01.raw_reads', "#{d.name}.done"), 'w'
    ) { |f| f.puts ':-)' }
    d.next_preprocessing(true)
    p2 = project('import_dataset')
    assert_empty(p2.datasets)
    assert_nil(p2.dataset('d1'))
    p2.import_dataset(d)
    assert_equal(1, p2.datasets.size)
    assert_equal(MiGA::Dataset, p2.dataset('d1').class)
    assert_equal(1, p2.dataset('d1').results.size)
    assert_path_exist(
      File.join(p2.path, 'data', '01.raw_reads', "#{d.name}.1.fastq")
    )
    assert_path_exist(File.join(p2.path, 'metadata', "#{d.name}.json"))
  end

  def test_add_result
    p1 = project
    assert_nil(p1.add_result(:doom))
    %w[.Rdata .log .txt .done].each do |x|
      assert_nil(p1.add_result(:haai_distances))
      FileUtils.touch(
        File.join(
          p1.path, 'data', '09.distances', '01.haai', "miga-project#{x}"
        )
      )
    end
    assert_equal(MiGA::Result, p1.add_result(:haai_distances).class)
  end

  def test_result
    p1 = project
    assert_nil(p1.result(:n00b))
    assert_nil(p1.result(:project_stats))
    json = File.join(p1.path, 'data', '90.stats', 'miga-project.json')
    File.open(json, 'w') { |fh| fh.puts '{}' }
    assert_not_nil(p1.result(:project_stats))
    assert_equal(1, p1.results.size)
  end

  def test_preprocessing
    p1 = project
    assert_predicate(p1, :done_preprocessing?)
    d1 = p1.add_dataset('BAH')
    assert_not_predicate(p1, :done_preprocessing?)
    FileUtils.touch(File.join(p1.path, 'data', '90.stats', "#{d1.name}.done"))
    assert { p1.done_preprocessing? true }
    assert_nil(p1.next_inclade)
    p1.metadata[:type] = :clade
    assert_equal(:subclades, p1.next_inclade)

    # Project tasks
    expected_files = {
      project_stats: %w[.taxonomy.json .metadata.db],
      haai_distances: %w[.Rdata .log .txt],
      aai_distances: %w[.Rdata .log .txt],
      ani_distances: %w[.Rdata .log .txt],
      clade_finding: %w[.pdf .classif .medoids
                        .class.tsv .class.nwk .proposed-clades],
      subclades: %w[.pdf .classif .medoids .class.tsv .class.nwk],
      ogs: %w[.ogs .stats]
    }
    expected_files.each do |r, exts|
      assert_equal(r, p1.next_task)
      create_result_files(p1, r, exts)
      assert_not_nil(p1.add_result(r), "Imposible to add #{r} result")
    end
    assert_nil(p1.next_task)
    p1.each_result { |k, r| assert_equal(k, r.key) }
  end

  def test_empty_results
    p1 = project
    p1.metadata[:type] = :clade
    %i[clade_finding subclades ogs].each do |r|
      assert_nil(p1.add_result(r), "Unexpected result exists: #{r}")
      create_result_files(p1, r, %w[.empty])
      assert_not_nil(p1.add_result(r), "Cannot register emtpy task: #{r}")
    end
  end

  def test_force_result
    p1 = project
    create_result_files(p1, :ogs, %w[.empty])
    date1 = p1.add_result(:ogs)[:created]
    sleep(1)
    date2 = p1.add_result(:ogs, true, force: false)[:created]
    assert_equal(date1, date2)
    date3 = p1.add_result(:ogs, true, force: true)[:created]
    assert_not_equal(date1, date3)
  end
end
