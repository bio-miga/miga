require 'test_helper'
require 'miga/project'

class ResultStatsTest < Test::Unit::TestCase

  def setup
    $tmp = Dir.mktmpdir
    ENV['MIGA_HOME'] = $tmp
    FileUtils.touch(File.expand_path('.miga_rc', ENV['MIGA_HOME']))
    FileUtils.touch(File.expand_path('.miga_daemon.json', ENV['MIGA_HOME']))
    $p = MiGA::Project.new(File.expand_path('project1', $tmp))
    $d = $p.add_dataset('dataset1')
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV['MIGA_HOME'] = nil
  end

  def file_path(dir, ext)
    File.join($p.path, dir, "#{$d.name}#{ext}")
  end

  def touch_done(dir)
    FileUtils.touch(file_path(dir, '.done'))
  end

  def test_single_raw_reads
    dir = 'data/01.raw_reads'
    fq = file_path(dir, '.1.fastq')
    File.open(fq, 'w') { |fh| fh.puts '@1','ACTAC','+','####' }
    touch_done(dir)
    r = $d.add_result(:raw_reads)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert(!r[:stats].empty?)
    assert_equal(Hash, r[:stats].class)
    assert_equal(1, r[:stats][:reads])
    assert_equal([40.0, '%'], r[:stats][:g_c_content])
  end

  def test_coupled_raw_reads
    dir = 'data/01.raw_reads'
    fq = file_path(dir, '.1.fastq')
    File.open(fq, 'w') { |fh| fh.puts '@1','ACTAC','+','####' }
    fq = file_path(dir, '.2.fastq')
    File.open(fq, 'w') { |fh| fh.puts '@1','ACTAC','+','####' }
    touch_done(dir)
    r = $d.add_result(:raw_reads)
    r.compute_stats
    assert(!r[:stats].empty?)
    assert_nil(r[:stats][:reads])
    assert_equal(1, r[:stats][:read_pairs])
    assert_equal([40.0, '%'], r[:stats][:reverse_g_c_content])
  end

  def test_trimmed_reads
    dir = 'data/02.trimmed_reads'
    FileUtils.touch(file_path(dir, '.1.clipped.fastq'))
    touch_done(dir)
    r = $d.add_result(:trimmed_reads)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal({}, r[:stats])
  end

  def test_read_quality
    dir = 'data/03.read_quality'
    Dir.mkdir(file_path(dir, '.solexaqa'))
    Dir.mkdir(file_path(dir, '.fastqc'))
    touch_done(dir)
    r = $d.add_result(:read_quality)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal({}, r[:stats])
  end

  def test_trimmed_fasta
    dir = 'data/04.trimmed_fasta'
    fa = file_path(dir, '.CoupledReads.fa')
    File.open(fa, 'w') { |fh| fh.puts '>1','ACTAC' }
    touch_done(dir)
    r = $d.add_result(:trimmed_fasta)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal(1, r[:stats][:reads])
    assert_equal([40.0, '%'], r[:stats][:g_c_content])
  end

  def test_assembly
    dir = 'data/05.assembly'
    fa = file_path(dir, '.LargeContigs.fna')
    File.open(fa, 'w') { |fh| fh.puts '>1','ACTAC' }
    touch_done(dir)
    r = $d.add_result(:assembly)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal(1, r[:stats][:contigs])
    assert_equal([5, 'bp'], r[:stats][:total_length])
    assert_equal([40.0, '%'], r[:stats][:g_c_content])
  end

  def test_cds
    dir = 'data/06.cds'
    fa = file_path(dir, '.faa')
    File.open(fa, 'w') { |fh| fh.puts '>1','M' }
    touch_done(dir)
    r = $d.add_result(:cds)
    assert_equal({}, r[:stats])
    r.compute_stats
    assert_equal(1, r[:stats][:predicted_proteins])
    assert_equal([1.0, 'aa'], r[:stats][:average_length])
    assert_nil(r[:stats][:coding_density])
    test_assembly
    r.compute_stats
    assert_equal([60.0, '%'], r[:stats][:coding_density])
  end

end
