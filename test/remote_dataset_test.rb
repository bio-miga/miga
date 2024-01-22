require 'test_helper'
require 'miga/project'
require 'miga/remote_dataset'

class RemoteDatasetTest < Test::Unit::TestCase
  include TestHelper

  def setup
    initialize_miga_home
    ENV.delete('NCBI_API_KEY')
  end

  def test_class_universe
    assert_respond_to(MiGA::RemoteDataset, :UNIVERSE)
    assert_include(MiGA::RemoteDataset.UNIVERSE.keys, :ebi)
  end

  def test_bad_remote_dataset
    assert_raise { MiGA::RemoteDataset.new('ids', :embl, :marvel) }
    assert_raise { MiGA::RemoteDataset.new('ids', :google, :ebi) }
  end

  def test_get
    hiv2 = 'M30502.1'
    { embl: :ebi, nuccore: :ncbi }.each do |db, universe|
      rd = MiGA::RemoteDataset.new(hiv2, db, universe)
      assert_equal([hiv2], rd.ids)

      declare_remote_access
      tx = rd.get_ncbi_taxonomy
      msg = "Failed on #{universe}:#{db}"
      assert_equal(MiGA::Taxonomy, tx.class, msg)
      assert_equal('Lentivirus', tx[:g], msg)
      assert_equal(
        'ns:ncbi k:Pararnavirae p:Artverviricota c:Revtraviricetes ' \
          'o:Ortervirales f:Retroviridae g:Lentivirus ' \
          's:Human_immunodeficiency_virus_2',
        tx.to_s, msg
      )
      assert_equal(
        'ns:ncbi d: k:Pararnavirae p:Artverviricota c:Revtraviricetes ' \
          'o:Ortervirales f:Retroviridae g:Lentivirus ' \
          's:Human_immunodeficiency_virus_2 ssp: str: ds:',
        tx.to_s(true), msg
      )
      assert_equal('ncbi', tx.namespace, msg)
    end
  end

  def test_net_ftp
    cjac = 'ftp://ftp.ebi.ac.uk/pub/databases/ena/tsa/' \
           'public/gap/GAPJ01.fasta.gz'
    n = 'Cjac_L14'
    rd = MiGA::RemoteDataset.new(cjac, :assembly_gz, :web)
    assert_equal([cjac], rd.ids)

    declare_remote_access
    p = project
    assert_nil(p.dataset(n))
    rd.save_to(p, n)
    p.add_dataset(n)
    assert_equal(MiGA::Dataset, p.dataset(n).class)
    assert_equal(MiGA::Result, p.dataset(n).result(:assembly).class)
  end

  def test_asm_acc2id
    declare_remote_access
    assert_raise(MiGA::RemoteDataMissingError) do
      MiGA::RemoteDataset.ncbi_asm_acc2id('NotAnAccession', 1)
    end
    id = MiGA::RemoteDataset.ncbi_asm_acc2id('GCA_004684205.1')
    assert_equal('2514661', id)
    assert_equal(id, MiGA::RemoteDataset.ncbi_asm_acc2id(id))
  end

  def test_update_metadata
    declare_remote_access
    hiv1 = 'GCF_000856385.1'
    d1 = MiGA::Dataset.new(project, 'd1')
    assert_nil(d1.metadata[:ncbi_assembly])
    rd = MiGA::RemoteDataset.new(hiv1, :assembly, :ncbi)
    rd.update_metadata(d1, passthrough: 123, metadata_only: true)
    assert_equal(123, d1.metadata[:passthrough])
    assert_equal(hiv1, d1.metadata[:ncbi_assembly])
    assert_equal('Lentivirus', d1.metadata[:tax][:g])
  end

  def test_type_status_asm
    declare_remote_access
    rd = MiGA::RemoteDataset.new('GCF_000018105.1', :assembly, :ncbi)
    md = rd.get_metadata
    assert(md[:is_type])
  end

  def test_nontype_status_asm
    declare_remote_access
    rd = MiGA::RemoteDataset.new('GCA_004684205.1', :assembly, :ncbi)
    md = rd.get_metadata
    assert(!md[:is_type])
  end

  def test_type_status_nuccore
    declare_remote_access
    rd = MiGA::RemoteDataset.new('NC_019748.1', :nuccore, :ncbi)
    md = rd.get_metadata
    assert(md[:is_type])
  end

  def test_ref_type_status
    declare_remote_access
    rd = MiGA::RemoteDataset.new('GCA_003144295.1', :assembly, :ncbi)
    md = rd.get_metadata
    assert(!md[:is_type])
    assert(md[:is_ref_type])
  end

  def test_gtdb_taxonomy
    declare_remote_access
    rd = MiGA::RemoteDataset.new('GCA_018200315.1', :assembly, :gtdb)
    md = rd.get_metadata
    assert(!md[:is_type])
    assert_not_nil(md[:gtdb_release])
    assert(md[:tax].is_a? MiGA::Taxonomy)
    assert_equal('GCA_018200315.1', md[:gtdb_assembly])
    assert_equal('gtdb', md[:tax][:ns])
    assert_equal('Bacteroidia', md[:tax][:c])
  end

  def test_gtdb_alt_taxonomy
    declare_remote_access
    rd = MiGA::RemoteDataset.new('GCA_018200315.1', :assembly, :gtdb)
    rd.metadata[:get_ncbi_taxonomy] = true
    md = rd.get_metadata
    assert(md[:tax].is_a? MiGA::Taxonomy)
    assert_equal('ncbi', md[:tax][:ns])
    assert_equal('Flavobacteriia', md[:tax][:c])
    assert(md[:tax].alternative(1).is_a? MiGA::Taxonomy)
    assert(md[:tax].alternative(:gtdb).is_a? MiGA::Taxonomy)
    assert_equal('gtdb', md[:tax].alternative(1)[:ns])
    assert_equal('gtdb', md[:tax].alternative(:gtdb)[:ns])
  end

  def test_missing_data
    declare_remote_access
    rd = MiGA::RemoteDataset.new('GCA_000484975.1', :assembly, :ncbi)
    assert_raise(MiGA::RemoteDataMissingError) { rd.save_to(project, 'bad') }
  end

  def test_gtdb_request
    # No remote access needed
    rd = MiGA::RemoteDataset.new('g__Macondimonas', :taxon, :gtdb)
    u = rd.download_uri
    h = rd.download_headers

    assert(u.is_a? URI)
    assert_equal('https', u.scheme)
    assert_equal('genomes', File.basename(u.path))

    assert(h.is_a? Hash)
    assert_equal(1, h.size)
    assert_equal('application/json', h['Accept'])
  end

  def test_ncbi_datasets_download_request
    # No remote access needed
    rd = MiGA::RemoteDataset.new(
      'GCF_004684205.1', :genome, :ncbi_datasets_download
    )
    u = rd.download_uri
    h = rd.download_headers

    assert(u.is_a? URI)
    assert_equal('https', u.scheme)
    assert_equal('download', File.basename(u.path))

    assert(h.is_a? Hash)
    assert_equal(1, h.size)
    assert_equal('application/zip', h['Accept'])

    ENV['NCBI_API_KEY'] = 'Not-a-real-key'
    h = rd.download_headers
    ENV.delete('NCBI_API_KEY')
    assert_equal(2, h.size)
    assert_equal('Not-a-real-key', h['api-key'])
  end

  def test_seqcode_request
    # No remote access needed
    rd = MiGA::RemoteDataset.new(nil, 'type-genomes', :seqcode)
    u = rd.download_uri

    assert(u.is_a? URI)
    assert_equal('https', u.scheme)
    assert_equal('type-genomes.json', File.basename(u.path))
  end

  def test_ncbi_datasets_request
    rd = MiGA::RemoteDataset.new({ taxons: 'Bos' }, :genome, :ncbi_datasets)
    u = rd.download_uri
    h = rd.download_headers
    p = rd.download_payload

    assert(u.is_a? URI)
    assert_equal('https', u.scheme)
    assert_equal('dataset_report', File.basename(u.path))

    assert(h.is_a? Hash)
    assert_equal(1, h.size)
    assert_equal('application/json', h['Content-Type'])

    assert(p.is_a? String)
    assert_equal('{', p[0])
    assert_equal('}', p[-1])
  end

  # This test is too expensive (too much time to run it!)
  # def test_net_timeout
  #   declare_remote_access
  #   bad = "ftp://example.com/miga"
  #   rd = MiGA::RemoteDataset.new(bad, :assembly, :web)
  #   assert_raise(Net::ReadTimeout) { rd.save_to(project, "bad") }
  # end
end
