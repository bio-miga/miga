require 'test_helper'
require 'miga/project'
require 'zlib'

class ResultStatsTest < Test::Unit::TestCase
  include TestHelper

  def setup
    initialize_miga_home
  end

  def file_path(dir, ext)
    File.join(project.path, dir, "#{dataset.name}#{ext}")
  end

  def touch_done(dir)
    FileUtils.touch(file_path(dir, '.done'))
  end

  def test_single_raw_reads
    dir = 'data/01.raw_reads'
    fq = file_path(dir, '.1.fastq')
    File.open(fq, 'w') { |fh| fh.puts '@1', 'ACTAC', '+', '####' }
    touch_done(dir)
    r = dataset.add_result(:raw_reads)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_not_empty(r[:stats])
    assert_equal(Hash, r[:stats].class)
    assert_equal(1, r[:stats][:reads])
    assert_equal([40.0, '%'], r[:stats][:g_c_content])
  end

  def test_coupled_raw_reads
    dir = 'data/01.raw_reads'
    fq = file_path(dir, '.1.fastq')
    File.open(fq, 'w') { |fh| fh.puts '@1', 'ACTAC', '+', '####' }
    fq = file_path(dir, '.2.fastq')
    File.open(fq, 'w') { |fh| fh.puts '@1', 'ACTAC', '+', '####' }
    touch_done(dir)
    r = dataset.add_result(:raw_reads)
    r.compute_stats
    assert_not_empty(r[:stats])
    assert_nil(r[:stats][:reads])
    assert_equal(1, r[:stats][:read_pairs])
    assert_equal([40.0, '%'], r[:stats][:reverse_g_c_content])
  end

  def test_trimmed_reads
    dir = 'data/02.trimmed_reads'
    FileUtils.touch(file_path(dir, '.1.clipped.fastq'))
    touch_done(dir)
    r = dataset.add_result(:trimmed_reads)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal({}, r[:stats])
  end

  def test_read_quality
    dir = 'data/03.read_quality'
    Dir.mkdir(file_path(dir, '.solexaqa'))
    Dir.mkdir(file_path(dir, '.fastqc'))
    touch_done(dir)
    r = dataset.add_result(:read_quality)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal({}, r[:stats])
  end

  def test_trimmed_fasta
    dir = 'data/04.trimmed_fasta'
    fa = file_path(dir, '.CoupledReads.fa')
    File.open(fa, 'w') { |fh| fh.puts '>1', 'ACTAC' }
    touch_done(dir)
    r = dataset.add_result(:trimmed_fasta)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal(1, r[:stats][:reads])
    assert_equal([40.0, '%'], r[:stats][:g_c_content])
  end

  def test_assembly
    # Prepare result
    dir = 'data/05.assembly'
    fa = file_path(dir, '.LargeContigs.fna')
    File.open(fa, 'w') { |fh| fh.puts '>1', 'ACTAC' }
    touch_done(dir)
    r = dataset.add_result(:assembly)

    # Test assertions
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal(1, r[:stats][:contigs])
    assert_equal([5, 'bp'], r[:stats][:total_length])
    assert_equal([40.0, '%'], r[:stats][:g_c_content])
  end

  def test_cds
    # Prepare result
    dir = 'data/06.cds'
    fa = file_path(dir, '.faa')
    File.open(fa, 'w') { |fh| fh.puts '>1', 'M' }
    gff = file_path(dir, '.gff3.gz')
    Zlib::GzipWriter.open(gff) do |fh|
      fh.puts '# Model Data: a=b;transl_table=11;'
    end
    touch_done(dir)
    r = dataset.add_result(:cds)

    # Test assertions
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal(1, r[:stats][:predicted_proteins])
    assert_equal([1.0, 'aa'], r[:stats][:average_length])
    assert_nil(r[:stats][:coding_density])
    test_assembly
    r.compute_stats
    assert_equal([60.0, '%'], r[:stats][:coding_density])
    assert_equal('11', r[:stats][:codon_table])
  end

  def test_taxonomy
    # Prepare result
    dir = 'data/09.distances/05.taxonomy'
    FileUtils.touch(file_path(dir, '.aai-medoids.tsv'))
    FileUtils.touch(file_path(dir, '.aai.db'))
    File.open(file_path(dir, '.intax.txt'), 'w') do |fh|
      fh.puts 'Closest relative: dad with AAI: 100.0.'
      3.times { fh.puts '' }
      fh.puts ' phylum Abc  0.0  **** '
    end
    touch_done(dir)
    r = dataset.add_result(:taxonomy)

    # Test assertions
    assert_nil(r[:stats][:closest_relative])
    r.compute_stats
    assert_equal('dad', r[:stats][:closest_relative])
    assert_equal([100.0, '%'], r[:stats][:aai])
    assert_equal(0.0, r[:stats][:phylum_pvalue])
  end
end
