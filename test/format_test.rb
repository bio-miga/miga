require 'test_helper'

class FormatTest < Test::Unit::TestCase
  include TestHelper

  def helper_write_file(content)
    f = tmpfile('f.fa')
    File.open(f, 'w') { |h| h.print content }
    f
  end

  def test_clean_fasta
    c = ">MyFa|not-good\nACTG123ACTG-XXNN*\n>GoodOne + spaces!\n\nA C T G .\n"
    cc = ">MyFa|not_good\nACTGACTG-XXNN\n>GoodOne + spaces!\nACTG.\n"
    f = helper_write_file(c)
    assert_equal(c, File.read(f))
    MiGA::MiGA.clean_fasta_file(f)
    assert_equal(cc, File.read(f))
  end

  def test_wrap_fasta
    c = ">MyFa\n" + ('X' * 150)
    cc = ">MyFa\n" + ('X' * 80) + "\n" + ('X' * 70) + "\n"
    f = helper_write_file(c)
    assert_equal(c, File.read(f))
    MiGA::MiGA.clean_fasta_file(f)
    assert_equal(cc, File.read(f))
  end

  def test_gz_fasta
    c = ">a-\na"
    cc = ">a_\na\n"
    f = helper_write_file(c)
    assert_equal(c, File.read(f))
    `gzip "#{f}"`
    MiGA::MiGA.clean_fasta_file("#{f}.gz")
    `gzip -d "#{f}.gz"`
    assert_equal(cc, File.read(f))
  end

  def test_seqs_length_fasta
    c = ">a\nACA\n>b\nACG\n>c\nACTGA\n>d\nGTGAG\n"
    f = helper_write_file(c)
    o = MiGA::MiGA.seqs_length(f, :fasta)
    assert_equal(4.0, o[:avg])
    assert_equal(1.0, o[:var])
    assert_equal(1.0, o[:sd])
    assert_nil(o[:gc])
    assert_nil(o[:n50])
    assert_nil(o[:med])
    o = MiGA::MiGA.seqs_length(f, :fasta, gc: true)
    assert_equal(50.0, o[:gc])
    assert_nil(o[:n50])
    o = MiGA::MiGA.seqs_length(f, :fasta, n50: true)
    assert_nil(o[:gc])
    assert_equal(5, o[:n50])
    o = MiGA::MiGA.seqs_length(f, :fasta, gc: true, n50: true)
    assert_equal(50.0, o[:gc])
    assert_equal(5, o[:n50])
    assert_equal(4.0, o[:med])
  end

  def test_seqs_length_fastq
    c = "@a\nac\n+\n!!\n@b\ntggg\n+\n####\n@c\nngt\n+\n!!!\n"
    f = helper_write_file(c)
    o = MiGA::MiGA.seqs_length(f, :fastq)
    assert_equal(3.0, o[:avg])
    assert_nil(o[:med])
    o = MiGA::MiGA.seqs_length(f, :fastq, n50: true)
    assert_equal(3, o[:med])
  end

  def test_tabulate
    tab = MiGA::MiGA.tabulate(%w[a b], [%w[123 45], %w[678 90]])
    assert_equal('  a  b ', tab[0])
    assert_equal('  -  - ', tab[1])
    assert_equal('123  45', tab[2])
    assert_equal('678  90', tab[3])
  end
end
