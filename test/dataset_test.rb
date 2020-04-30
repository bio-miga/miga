require 'test_helper'
require 'miga/project'

class DatasetTest < Test::Unit::TestCase
  def setup
    $tmp = Dir.mktmpdir
    ENV['MIGA_HOME'] = $tmp
    FileUtils.touch(File.expand_path('.miga_rc', ENV['MIGA_HOME']))
    FileUtils.touch(File.expand_path('.miga_daemon.json', ENV['MIGA_HOME']))
    $p1 = MiGA::Project.new(File.expand_path('project1', $tmp))
    $d1 = $p1.add_dataset('dataset1')
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV['MIGA_HOME'] = nil
  end

  def test_known_types
    assert_respond_to(MiGA::Dataset, :KNOWN_TYPES)
    assert { MiGA::Dataset.KNOWN_TYPES.has_key?(:genome) }
  end

  def test_exist
    assert_respond_to(MiGA::Dataset, :exist?)
    assert { MiGA::Dataset.exist?($p1, 'dataset1') }
    assert { !MiGA::Dataset.exist?($p1, 'Nope') }
  end

  def test_info_fields
    assert_respond_to(MiGA::Dataset, :INFO_FIELDS)
    assert { MiGA::Dataset.INFO_FIELDS.include?('name') }
  end

  def test_initialize
    assert_raise { MiGA::Dataset.new($p1, 'dataset-1') }
    assert_equal($p1, $d1.project)
    assert_equal('dataset1', $d1.name)
    assert_predicate($d1, :is_ref?)
    assert_equal(MiGA::Metadata, $d1.metadata.class)
    assert_equal(:incomplete, $d1.status)
  end

  def test_save
    d2 = $p1.add_dataset('ds_save')
    assert_respond_to(d2, :save)
    d2.save
    assert_not_predicate(d2, :is_multi?)
    assert_not_predicate(d2, :is_nonmulti?)
    assert_nil(d2.metadata[:type])
    d2.metadata[:type] = :metagenome
    d2.save
    assert_equal(:metagenome, d2.metadata[:type])
    assert_predicate(d2, :is_multi?)
    assert_not_predicate(d2, :is_nonmulti?)
  end

  def test_remove
    d2 = $p1.add_dataset('ds_remove')
    assert_path_exist(d2.metadata.path)
    d2.remove!
    assert_path_not_exist(d2.metadata.path)
  end

  def test_info
    assert_equal($d1.name, $d1.info.first)
  end

  def test_add_result
    d2 = $p1.add_dataset('ds_add_result')
    assert_nil(d2.add_result(:koop))
    assert_nil(d2.add_result(:raw_reads))
    FileUtils.touch(
      File.expand_path("data/01.raw_reads/#{d2.name}.1.fastq", $p1.path)
    )
    assert_nil(d2.add_result(:raw_reads))
    FileUtils.touch(
      File.expand_path("data/01.raw_reads/#{d2.name}.done", $p1.path)
    )
    assert_equal(MiGA::Result, d2.add_result(:raw_reads).class)
  end

  def test_preprocessing
    d2 = $p1.add_dataset('ds_preprocessing')
    assert_nil(d2.first_preprocessing)
    assert_nil(d2.next_preprocessing)
    assert_not_predicate(d2, :done_preprocessing?)
    FileUtils.touch(File.expand_path(
                      "data/02.trimmed_reads/#{d2.name}.1.clipped.fastq", $p1.path
                    ))
    FileUtils.touch(File.expand_path(
                      "data/02.trimmed_reads/#{d2.name}.done", $p1.path
                    ))
    assert_equal(:trimmed_reads, d2.first_preprocessing(true))
    assert_equal(:read_quality, d2.next_preprocessing(true))
    assert { !d2.done_preprocessing?(true) }
    # Ref and undeclared multi
    assert { d2.ignore_task?(:mytaxa) }
    assert { d2.ignore_task?(:mytaxa_scan) }
    assert { d2.ignore_task?(:distances) }
    # Ref and multi
    d2.metadata[:type] = :metagenome
    assert { !d2.ignore_task?(:mytaxa) }
    assert { d2.ignore_task?(:mytaxa_scan) }
    assert { d2.ignore_task?(:distances) }
    # Ref and nonmulti
    d2.metadata[:type] = :genome
    assert { d2.ignore_task?(:mytaxa) }
    assert { !d2.ignore_task?(:mytaxa_scan) }
    assert { !d2.ignore_task?(:distances) }
    # Qry and nonmulti
    d2.metadata[:ref] = false
    assert { d2.ignore_task?(:mytaxa) }
    assert { d2.ignore_task?(:mytaxa_scan) }
    assert { !d2.ignore_task?(:distances) }
  end

  def test_profile_advance
    d2 = $p1.add_dataset('ds_profile_advance')
    assert_equal(0, d2.profile_advance(true).first)
    assert_equal(0, d2.profile_advance(true).last)
    assert_equal(0, d2.profile_advance(true).inject(:+))
    Dir.mkdir(File.expand_path(
                "data/03.read_quality/#{d2.name}.solexaqa", $p1.path
              ))
    Dir.mkdir(File.expand_path(
                "data/03.read_quality/#{d2.name}.fastqc", $p1.path
              ))
    FileUtils.touch(File.expand_path(
                      "data/03.read_quality/#{d2.name}.done", $p1.path
                    ))
    assert_equal([0, 0, 1, 2], d2.profile_advance(true)[0..3])
    assert_equal(2, d2.profile_advance(true).last)
  end

  def test_add_result_other
    d2 = $p1.add_dataset('ds_add_result_other')
    Dir.mkdir(File.expand_path(
                "data/07.annotation/01.function/01.essential/#{d2.name}.ess", $p1.path
              ))
    to_test = {
      trimmed_fasta: [
        "data/04.trimmed_fasta/#{d2.name}.SingleReads.fa",
        "data/04.trimmed_fasta/#{d2.name}.done"
      ],
      assembly: [
        "data/05.assembly/#{d2.name}.LargeContigs.fna",
        "data/05.assembly/#{d2.name}.done"
      ],
      cds: [
        "data/06.cds/#{d2.name}.faa",
        "data/06.cds/#{d2.name}.fna",
        "data/06.cds/#{d2.name}.done"
      ],
      essential_genes: %w[ess.faa ess/log done]
              .map do |x|
                         "data/07.annotation/01.function/01.essential/#{d2.name}.#{x}"
                       end,
      ssu: [
        "data/07.annotation/01.function/02.ssu/#{d2.name}.ssu.fa",
        "data/07.annotation/01.function/02.ssu/#{d2.name}.done"
      ],
      mytaxa_scan: %w[pdf wintax mytaxa reg done]
              .map do |x|
                     "data/07.annotation/03.qa/02.mytaxa_scan/#{d2.name}.#{x}"
                   end,
      distances: [
        "data/09.distances/01.haai/#{d2.name}.db",
        "data/09.distances/#{d2.name}.done"
      ]
    }
    to_test.each do |k, v|
      assert_nil(d2.add_result(k), "Result for #{k} should be nil.")
      v.each { |i| FileUtils.touch(File.expand_path(i, $p1.path)) }
      FileUtils.touch(File.expand_path(
                        "data/04.trimmed_fasta/#{d2.name}.done", $p1.path
                      ))
      assert_equal(
        MiGA::Result,
        d2.add_result(k).class,
        "Result for #{k} should be MiGA::Result."
      )
    end
  end

  def test_activate
    d = $d1
    assert_equal(:incomplete, d.status)
    assert_predicate(d, :active?)
    d.inactivate!
    assert_equal(:inactive, d.status)
    assert_not_predicate(d, :active?)
    d.activate!
    assert_equal(:incomplete, d.status)
    assert_predicate(d, :active?)
  end
end
