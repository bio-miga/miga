require 'test_helper'
require 'miga/project'

class ProjectTest < Test::Unit::TestCase

  def setup
    $tmp = Dir.mktmpdir
    ENV['MIGA_HOME'] = $tmp
    FileUtils.touch(File.expand_path('.miga_rc', ENV['MIGA_HOME']))
    FileUtils.touch(File.expand_path('.miga_daemon.json', ENV['MIGA_HOME']))
    $p1 = MiGA::Project.new(File.expand_path('project1', $tmp))
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV['MIGA_HOME'] = nil
  end

  def test_class_load
    assert_nil(MiGA::Project.load($tmp + '/O_o'))
    assert_equal(MiGA::Project, MiGA::Project.load($p1.path).class)
  end

  def test_create
    assert_equal("#{$tmp}/create", MiGA::Project.new("#{$tmp}/create").path)
    assert(Dir.exist?("#{$tmp}/create"))
    assert_raise do
      ENV['MIGA_HOME'] = $tmp + '/chez-moi'
      MiGA::Project.new($tmp + '/cuckoo')
    end
  ensure
    ENV['MIGA_HOME'] = $tmp
  end

  def test_load
    p = MiGA::Project.new($tmp + '/load')
    assert_equal(MiGA::Project, p.class)
    File.unlink p.metadata.path
    assert_raise do
      p.load
    end
  end

  def test_datasets
    p = $p1
    d = p.add_dataset('d1')
    assert_equal(MiGA::Dataset, d.class)
    assert_equal([d], p.datasets)
    assert_equal(['d1'], p.dataset_names)
    p.each_dataset{ |ds| assert_equal(d, ds) }
    dr = p.unlink_dataset('d1')
    assert_equal(d, dr)
    assert_equal([], p.datasets)
    assert_equal([], p.dataset_names)
  end

  def test_import_dataset
    p1 = $p1
    d1 = p1.add_dataset('d1')
    File.open(
      "#{p1.path}/data/01.raw_reads/#{d1.name}.1.fastq", 'w'
    ) { |f| f.puts ':-)' }
    File.open(
      "#{p1.path}/data/01.raw_reads/#{d1.name}.done", 'w'
    ) { |f| f.puts ':-)' }
    d1.next_preprocessing(true)
    p2 = MiGA::Project.new(File.expand_path('import_dataset', $tmp))
    assert(p2.datasets.empty?)
    assert_nil(p2.dataset('d1'))
    p2.import_dataset(d1)
    assert_equal(1, p2.datasets.size)
    assert_equal(MiGA::Dataset, p2.dataset('d1').class)
    assert_equal(1, p2.dataset('d1').results.size)
    assert(File.exist?(
      File.expand_path("data/01.raw_reads/#{d1.name}.1.fastq", p2.path)
    ))
    assert(File.exist?(
      File.expand_path("metadata/#{d1.name}.json", p2.path)
    ))
  end

  def test_add_result
    p1 = $p1
    assert_nil(p1.add_result(:doom))
    %w[.Rdata .log .txt .done].each do |x|
      assert_nil(p1.add_result(:haai_distances))
      FileUtils.touch(
        File.expand_path("data/09.distances/01.haai/miga-project#{x}",p1.path)
      )
    end
    assert_equal(MiGA::Result, p1.add_result(:haai_distances).class)
  end

  def test_result
    p1 = $p1
    assert_nil(p1.result :n00b)
    assert_nil(p1.result :project_stats)
    File.open(
      File.expand_path('data/90.stats/miga-project.json', p1.path), 'w'
    ) { |fh| fh.puts '{}' }
    assert_not_nil(p1.result :project_stats)
    assert_equal(1, p1.results.size)
  end

  def test_preprocessing
    p1 = $p1
    assert(p1.done_preprocessing?)
    d1 = p1.add_dataset('BAH')
    assert(!p1.done_preprocessing?)
    FileUtils.touch(File.expand_path("data/90.stats/#{d1.name}.done", p1.path))
    assert(p1.done_preprocessing?)

    # Project stats
    assert_equal(:project_stats, p1.next_distances)
    d = MiGA::Project.RESULT_DIRS[:project_stats]
    %w[.done .taxonomy.json .metadata.db].each do |x|
      assert_nil(
        p1.add_result(:project_stats),
        "Premature registration of result project_stats at extension #{x}."
      )
      FileUtils.touch(File.expand_path("data/#{d}/miga-project#{x}", p1.path))
    end
    assert_equal(MiGA::Result, p1.add_result(:project_stats).class,
      'Imposible to add project_stats result.')

    # Distances
    [:haai_distances, :aai_distances, :ani_distances].each do |r|
      assert_equal(r, p1.next_distances)
      assert_equal(Symbol, p1.next_distances.class)
      d = MiGA::Project.RESULT_DIRS[r]
      %w[.done .Rdata .log .txt].each do |x|
        assert_nil(
          p1.add_result(r),
          "Premature registration of result #{r} at extension #{x}."
        )
        FileUtils.touch(File.expand_path("data/#{d}/miga-project#{x}", p1.path))
      end
      assert_equal(MiGA::Result, p1.add_result(r).class,
        "Imposible to add #{r} result.")
    end
    assert_equal(:clade_finding, p1.next_distances)

    # Clades
    assert_nil(p1.next_inclade)
    p1.metadata[:type] = :clade
    res = [
      [:clade_finding,
        %w[.pdf .classif .medoids .class.tsv .class.nwk .proposed-clades]],
      [:subclades, %w[.pdf .classif .medoids .class.tsv .class.nwk]],
      [:ogs, %w[.ogs .stats]]
    ]
    res.each do |rr|
      (r, xs) = rr
      d = MiGA::Project.RESULT_DIRS[r]
      assert_equal(Symbol, p1.next_inclade.class)
      ([".done"] + xs).each do |x|
        assert_nil(
          p1.add_result(r),
          "Premature registration of result #{r} at extension #{x}."
        )
        FileUtils.touch(File.expand_path("data/#{d}/miga-project#{x}", p1.path))
      end
      assert_equal(
        MiGA::Result,
        p1.add_result(r).class,
        "Impossible to add #{r} result."
      )
    end
    assert_nil(p1.next_inclade)
  end

end
