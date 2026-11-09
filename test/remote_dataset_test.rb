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
          's:Lentivirus_humimdef2 ' \
          'ds:Human_immunodeficiency_virus_2',
        tx.to_s, msg
      )
      assert_equal(
        'ns:ncbi d: k:Pararnavirae p:Artverviricota c:Revtraviricetes ' \
          'o:Ortervirales f:Retroviridae g:Lentivirus ' \
          's:Lentivirus_humimdef2 ssp: str: ' \
          'ds:Human_immunodeficiency_virus_2',
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
    rd = MiGA::RemoteDataset.new('XYZ_GCA_000484975.1', :assembly, :ncbi)
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

  def test_ncbi_datasets_report_request
    # No remote access needed
    rd = MiGA::RemoteDataset.new(
      'GCA_000175575', :genome, :ncbi_datasets_report
    )
    u = rd.download_uri
    h = rd.download_headers

    assert(u.is_a? URI)
    assert_equal('https', u.scheme)
    assert_equal('dataset_report', File.basename(u.path))
    assert_include(u.path, '/accession/GCA_000175575/')

    assert(h.is_a? Hash)
    assert_equal(1, h.size)
    assert_equal('application/json', h['Accept'])

    ENV['NCBI_API_KEY'] = 'Not-a-real-key'
    h = rd.download_headers
    ENV.delete('NCBI_API_KEY')
    assert_equal(2, h.size)
    assert_equal('Not-a-real-key', h['api-key'])
  end

  def test_ncbi_asm_resolve_acc_offline
    report = {
      'GCA_000175575' =>
        '{"reports":[{"accession":"GCA_000175575.2",' \
        '"current_accession":"GCA_000175575.2"}]}',
      'GCA_999999999' => '{}',
      'GCA_888888888' => '{"error":"Too Many Requests","code":429}',
      'GCA_777777777' => '<html>Service unavailable</html>'
    }
    calls = []
    with_stubbed_download(lambda do |universe, _db, ids, *_rest|
      assert_equal(:ncbi_datasets_report, universe)
      calls << ids
      report[ids]
    end) do
      rd = MiGA::RemoteDataset
      assert_equal('GCA_000175575.2', rd.ncbi_asm_resolve_acc('GCA_000175575'))
      assert_equal(['GCA_000175575'], calls)

      # Versioned (or non-assembly) accessions are not resolved
      assert_equal('GCF_000175575.2', rd.ncbi_asm_resolve_acc('GCF_000175575.2'))
      assert_equal('M30502.1', rd.ncbi_asm_resolve_acc('M30502.1'))
      assert_equal(1, calls.size)

      # Missing accessions
      assert_raise(MiGA::RemoteDataMissingError) do
        rd.ncbi_asm_resolve_acc('GCA_999999999')
      end

      # Unexpected responses are not reported as missing data
      %w[GCA_888888888 GCA_777777777].each do |acc|
        err = assert_raise(MiGA::RemoteDataError) do
          rd.ncbi_asm_resolve_acc(acc)
        end
        assert_not_instance_of(MiGA::RemoteDataMissingError, err)
      end
    end
  end

  def test_ncbi_asm_get_bad_zip_offline
    require 'zip'
    # A truncated archive like the one NCBI returns for unversioned accessions
    truncated = "PK\x03\x04\x14\x00\x00\x00\x08\x00README.md".b
    # A valid archive without any genomic FastA file
    no_fna = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry('README.md')
      zos.write('Nothing to see here')
    end.string

    [truncated, no_fna].each do |zipped|
      with_stubbed_download(lambda do |universe, *_rest|
        assert_equal(:ncbi_datasets_download, universe)
        zipped
      end) do
        file = tmpfile('asm.fna')
        err = assert_raise(MiGA::RemoteDataMissingError) do
          MiGA::RemoteDataset.ncbi_asm_get(
            ids: ['GCA_000175575.2'], file: file, extra: {}
          )
        end
        assert_include(err.message, 'GCA_000175575.2')
      end
    end
  end

  def test_ncbi_asm_get_offline
    require 'zip'
    zipped = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry(
        'ncbi_dataset/data/GCA_000175575.2/GCA_000175575.2_ASM_genomic.fna'
      )
      zos.write(">ctg1\nACGT\n")
    end.string
    report =
      '{"reports":[{"accession":"GCA_000175575.2",' \
      '"current_accession":"GCA_000175575.2"}]}'

    rd = MiGA::RemoteDataset.new('GCA_000175575', :assembly, :ncbi)
    with_stubbed_download(lambda do |universe, _db, ids, *_rest|
      case universe
      when :ncbi_datasets_report
        report
      when :ncbi_datasets_download
        assert_equal(['GCA_000175575.2'], ids)
        zipped
      end
    end) do
      file = tmpfile('asm.fna')
      o = MiGA::RemoteDataset.ncbi_asm_get(
        ids: rd.ids, file: file, extra: {}, obj: rd
      )
      assert_equal(">ctg1\nACGT\n", o)
      assert_equal(">ctg1\nACGT\n", File.read(file))
      assert_equal('GCA_000175575.2', rd.metadata[:ncbi_asm])
      assert_equal('GCA_000175575', rd.metadata[:ncbi_assembly])
    end
  end

  def test_ncbi_asm_resolve_acc
    declare_remote_access
    rd = MiGA::RemoteDataset
    assert_equal('GCA_000175575.2', rd.ncbi_asm_resolve_acc('GCA_000175575'))
    assert_equal('GCF_000175575.2', rd.ncbi_asm_resolve_acc('GCF_000175575'))
    assert_raise(MiGA::RemoteDataMissingError) do
      rd.ncbi_asm_resolve_acc('GCA_999999999')
    end
  end

  def test_ncbi_asm_unversioned
    declare_remote_access
    rd = MiGA::RemoteDataset.new('GCA_000175575', :assembly, :ncbi)
    ds = rd.save_to(project, 'unversioned')
    assert_equal('GCA_000175575.2', ds.metadata[:ncbi_asm])
    fna = ds.result(:assembly).file_path(:largecontigs)
    assert_path_exist(fna)
    assert_operator(File.size(fna), :>, 100_000)
  end

  # This test is too expensive (too much time to run it!)
  # def test_net_timeout
  #   declare_remote_access
  #   bad = "ftp://example.com/miga"
  #   rd = MiGA::RemoteDataset.new(bad, :assembly, :web)
  #   assert_raise(Net::ReadTimeout) { rd.save_to(project, "bad") }
  # end

  private

  ##
  # Temporarily replace MiGA::RemoteDataset.download with +fun+ while running
  # the given block
  def with_stubbed_download(fun)
    klass = MiGA::RemoteDataset.singleton_class
    klass.send(:alias_method, :__orig_download, :download)
    klass.send(:define_method, :download) { |*args| fun.call(*args) }
    yield
  ensure
    klass.send(:alias_method, :download, :__orig_download)
    klass.send(:remove_method, :__orig_download)
  end
end
