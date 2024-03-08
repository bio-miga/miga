# @package MiGA
# @license Artistic-2.0

require 'miga/taxonomy'
require 'miga/remote_dataset/download'

##
# MiGA representation of datasets with data in remote locations.
class MiGA::RemoteDataset < MiGA::MiGA
  include MiGA::RemoteDataset::Download

  # Class-level

  class << self
    ##
    # Path to a directory with a recent NCBI Taxonomy dump to use instead of
    # making API calls to NCBI servers, which can be obtained at:
    # https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
    #
    # The +cli+ parameter, if passed, should be a MiGA::Cli object that will
    # be used to report advance in the reading. Other objects can be passed,
    # minimally supporting the MiGA::Cli#say and MiGA::Cli#advance method
    # interfaces
    def use_ncbi_taxonomy_dump(path, cli = nil)
      raise "Directory doesn't exist: #{path}" unless File.directory?(path)

      # Structure: { TaxID => ["name", "rank", parent TaxID] }
      MiGA::MiGA.DEBUG "Loading NCBI Taxonomy dump: #{path}"
      @ncbi_taxonomy_names = {}

      # Read names.dmp
      File.open(file = File.join(path, 'names.dmp')) do |fh|
        read = 0
        size = File.size(file)
        fh.each do |ln|
          cli&.advance('- names.dmp:', read += ln.size, size)
          row = ln.split(/\t\|\t?/)
          next unless row[3] == 'scientific name'
          @ncbi_taxonomy_names[row[0].to_i] = [row[1].strip]
        end
        cli&.say
      end

      # Read nodes.dmp
      File.open(file = File.join(path, 'nodes.dmp')) do |fh|
        read = 0
        size = File.size(file)
        fh.each do |ln|
          cli&.advance('- nodes.dmp:', read += ln.size, size)
          row = ln.split(/\t\|\t?/)
          child  = row[0].to_i
          parent = row[1].to_i
          @ncbi_taxonomy_names[child][1] = row[2]
          @ncbi_taxonomy_names[child][2] = parent unless parent == child
        end
        cli&.say
      end
    end

    ##
    # Is a local NCBI Taxonomy dump available?
    def ncbi_taxonomy_dump?
      (@ncbi_taxonomy_names ||= nil) ? true : false
    end

    ##
    # Get the MiGA::Taxonomy object for the lineage of the taxon with TaxID
    # +id+ using the local NCBI Taxonomy dump.
    def taxonomy_from_ncbi_dump(id)
      id = id.to_i unless id.is_a? Integer
      MiGA::Taxonomy.new(ns: 'ncbi').tap do |tax|
        while @ncbi_taxonomy_names[id]
          tax << { @ncbi_taxonomy_names[id][1] => @ncbi_taxonomy_names[id][0] }
          id = @ncbi_taxonomy_names[id][2]
        end
      end
    end

    ##
    # Translate an NCBI Assembly Accession (+acc+) to corresponding internal
    # NCBI ID, with up to +retrials+ retrials if the returned JSON document
    # does not conform to the expected format
    def ncbi_asm_acc2id(acc, retrials = 3)
      return acc if acc =~ /^\d+$/

      search_doc = MiGA::Json.parse(
        download(:ncbi_search, :assembly, acc, :json),
        symbolize: false, contents: true
      )
      out = (search_doc['esearchresult']['idlist'] || []).first
      if out.nil?
        raise MiGA::RemoteDataMissingError.new(
          "NCBI Assembly Accession not found: #{acc}"
        )
      end
      return out
    rescue JSON::ParserError, MiGA::RemoteDataMissingError => e
      # Note that +JSON::ParserError+ is being rescued because the NCBI backend
      # may in some cases return a malformed JSON response indicating that the
      # "Search Backend failed". The issue with the JSON payload is that it
      # includes two tab characters (\t\t) in the error message, which is not
      # allowed by the JSON specification and causes a parsing error
      # (see https://www.rfc-editor.org/rfc/rfc4627#page-4)

      if retrials <= 0
        raise e
      else
        MiGA::MiGA.DEBUG("#{self}.ncbi_asm_acc2id - RETRY #{retrials}")
        retrials -= 1
        retry
      end
    end
  end

  # Instance-level

  ##
  # Universe of the dataset.
  attr_reader :universe
  # Database storing the dataset.
  attr_reader :db
  # Array of IDs of the entries composing the dataset.
  attr_reader :ids
  # Internal metadata hash
  attr_reader :metadata
  # NCBI Assembly XML document
  @_ncbi_asm_xml_doc = nil

  ##
  # Initialize MiGA::RemoteDataset with +ids+ in database +db+ from +universe+.
  def initialize(ids, db, universe)
    ids = [ids] unless ids.is_a? Array
    @ids = (ids.is_a?(Array) ? ids : [ids])
    @db = db.to_sym
    @universe = universe.to_sym
    @metadata = {}
    @metadata[:"#{universe}_#{db}"] = ids.join(',')
    @@UNIVERSE.keys.include?(@universe) or
      raise "Unknown Universe: #{@universe}. Try: #{@@UNIVERSE.keys}"
    @@UNIVERSE[@universe][:dbs].include?(@db) or
      raise "Unknown Database: #{@db}. Try: #{@@UNIVERSE[@universe][:dbs].keys}"
    @_ncbi_asm_json_doc = nil
    # FIXME: Part of the +map_to+ support:
    # unless @@UNIVERSE[@universe][:dbs][@db][:map_to].nil?
    #   MiGA::RemoteDataset.download
    # end
  end

  ##
  # Save dataset to the MiGA::Project +project+ identified with +name+. +is_ref+
  # indicates if it should be a reference dataset, and contains +metadata_def+.
  # If +metadata_def+ includes +metadata_only: true+, no input data is
  # downloaded.
  def save_to(project, name = nil, is_ref = true, metadata_def = {})
    name ||= ids.join('_').miga_name
    project = MiGA::Project.new(project) if project.is_a? String
    MiGA::Dataset.exist?(project, name) and
      raise "Dataset #{name} exists in the project, aborting..."
    @metadata = get_metadata(metadata_def)
    udb = @@UNIVERSE[universe][:dbs][db]
    @metadata["#{universe}_#{db}"] = ids.join(',')
    unless @metadata[:metadata_only]
      respond_to?("save_#{udb[:stage]}_to", true) or
        raise "Unexpected error: Unsupported stage #{udb[:stage]} for #{db}."
      send "save_#{udb[:stage]}_to", project, name, udb
    end
    dataset = MiGA::Dataset.new(project, name, is_ref, metadata)
    project.add_dataset(dataset.name)
    unless @metadata[:metadata_only]
      result = dataset.add_result(udb[:stage], true, is_clean: true)
      result.nil? and
        raise 'Empty dataset: seed result not added due to incomplete files.'
      result.clean!
      result.save
    end
    dataset
  end

  ##
  # Updates the MiGA::Dataset +dataset+ with the remotely available metadata,
  # and optionally the Hash +metadata+.
  def update_metadata(dataset, metadata = {})
    metadata = get_metadata(metadata)
    metadata.each { |k, v| dataset.metadata[k] = v }
    dataset.save
  end

  ##
  # Get metadata from the remote location.
  def get_metadata(metadata_def = {})
    metadata_def.each { |k, v| @metadata[k] = v }
    return @metadata if @metadata[:bypass_metadata]

    case universe
    when :ebi, :ncbi, :web
      # Get taxonomy
      @metadata[:tax] = get_ncbi_taxonomy
    when :gtdb
      # Get taxonomy
      @metadata[:tax] = get_gtdb_taxonomy
    when :seqcode
      # Taxonomy already defined
      # Copy IDs over to allow additional metadata linked
      @metadata[:ncbi_asm] = @metadata[:seqcode_asm]
      @metadata[:ncbi_nuccore] = @metadata[:seqcode_nuccore]
    end

    if metadata[:get_ncbi_taxonomy]
      tax = get_ncbi_taxonomy
      tax&.add_alternative(@metadata[:tax].dup, false) if @metadata[:tax]
      @metadata[:tax] = tax
    end
    @metadata[:get_ncbi_taxonomy] = nil
    @metadata = get_type_status(metadata)
  end

  ##
  # Get NCBI Taxonomy ID.
  def get_ncbi_taxid
    send("get_ncbi_taxid_from_#{universe}")
  end

  ##
  # Get the type material status and return an (updated)
  # +metadata+ hash.
  def get_type_status(metadata)
    if metadata[:ncbi_asm]
      get_type_status_ncbi_asm(metadata)
    elsif metadata[:ncbi_nuccore]
      get_type_status_ncbi_nuccore(metadata)
    else
      metadata
    end
  end

  ##
  # Get NCBI taxonomy as MiGA::Taxonomy
  def get_ncbi_taxonomy
    tax_id = get_ncbi_taxid or return

    if self.class.ncbi_taxonomy_dump?
      return self.class.taxonomy_from_ncbi_dump(tax_id)
    end

    lineage = { ns: 'ncbi' }
    doc = MiGA::RemoteDataset.download(:ncbi, :taxonomy, tax_id, :xml)
    doc.scan(%r{<Taxon>(.*?)</Taxon>}m).map(&:first).each do |i|
      name = i.scan(%r{<ScientificName>(.*)</ScientificName>}).first.to_a.first
      rank = i.scan(%r{<Rank>(.*)</Rank>}).first.to_a.first
      rank = nil if rank.nil? || rank == 'no rank' || rank.empty?
      rank = 'dataset' if lineage.size == 1 && rank.nil?
      lineage[rank] = name unless rank.nil? || name.nil?
    end
    MiGA.DEBUG "Got lineage: #{lineage}"
    MiGA::Taxonomy.new(lineage)
  end

  ##
  # Get GTDB taxonomy as MiGA::Taxonomy
  def get_gtdb_taxonomy
    gtdb_genome = metadata[:gtdb_assembly] or return

    doc = MiGA::Json.parse(
      MiGA::RemoteDataset.download(
        :gtdb, :genome, gtdb_genome, 'taxon-history'
      ),
      contents: true
    )
    lineage = { ns: 'gtdb' }
    lineage.merge!(doc.first) # Get only the latest available classification
    release = lineage.delete(:release)
    @metadata[:gtdb_release] = release
    lineage.transform_values! { |v| v.gsub(/^\S__/, '') }
    MiGA.DEBUG "Got lineage from #{release}: #{lineage}"
    MiGA::Taxonomy.new(lineage)
  end

  ##
  # Get the JSON document describing an NCBI assembly entry.
  def ncbi_asm_json_doc
    return @_ncbi_asm_json_doc unless @_ncbi_asm_json_doc.nil?

    if db == :assembly && %i[ncbi gtdb seqcode].include?(universe)
      metadata[:ncbi_asm] ||= ids.first
    end
    return nil unless metadata[:ncbi_asm]

    ncbi_asm_id = self.class.ncbi_asm_acc2id(metadata[:ncbi_asm])
    txt = nil
    3.times do
      txt = self.class.download(:ncbi_summary, :assembly, ncbi_asm_id, :json)
      txt.empty? ? sleep(1) : break
    end
    doc = MiGA::Json.parse(txt, symbolize: false, contents: true)
    return if doc.nil? || doc['result'].nil? || doc['result'].empty?

    @_ncbi_asm_json_doc = doc['result'][ doc['result']['uids'].first ]
    url_dir = @_ncbi_asm_json_doc['ftppath_genbank']
    if url_dir
      metadata[:web_assembly_gz] ||=
        '%s/%s_genomic.fna.gz' % [url_dir, File.basename(url_dir)]
    end
    @_ncbi_asm_json_doc
  end

  private

  def get_ncbi_taxid_from_web
    # Check first if metadata was pulled from NCBI already
    taxid = metadata.dig(:ncbi_dataset, :organism, :tax_id)
    return taxid if taxid

    # Otherwise, try to get the Assembly JSON document
    ncbi_asm_json_doc&.dig('taxid')
  end

  def get_ncbi_taxid_from_ncbi
    # Try first from Assembly data
    return get_ncbi_taxid_from_web if db == :assembly

    # Try from previously pulled NCBI data
    taxid = metadata.dig(:ncbi_dataset, :organism, :tax_id)
    return taxid if taxid

    # Try from GenBank document (obtain it)
    doc = self.class.download(:ncbi, db, ids, :gb, nil, {}, self).split(/\n/)
    ln = doc.grep(%r{^\s+/db_xref="taxon:}).first
    return nil if ln.nil?

    ln.sub!(/.*(?:"taxon:)(\d+)["; ].*/, '\\1')
    return nil unless ln =~ /^\d+$/

    ln
  end

  alias :get_ncbi_taxid_from_seqcode :get_ncbi_taxid_from_ncbi
  alias :get_ncbi_taxid_from_gtdb :get_ncbi_taxid_from_ncbi

  def get_ncbi_taxid_from_ebi
    doc = self.class.download(:ebi, db, ids, :annot).split(/\n/)
    ln = doc.grep(%r{^FT\s+/db_xref="taxon:}).first
    ln = doc.grep(/^OX\s+NCBI_TaxID=/).first if ln.nil?
    return nil if ln.nil?

    ln.sub!(/.*(?:"taxon:|NCBI_TaxID=)(\d+)["; ].*/, '\\1')
    return nil unless ln =~ /^\d+$/

    ln
  end

  def get_type_status_ncbi_nuccore(metadata)
    return metadata if metadata[:ncbi_nuccore].nil?

    biosample =
      self.class.ncbi_map(metadata[:ncbi_nuccore], :nuccore, :biosample)
    return metadata if biosample.nil?

    asm = self.class.ncbi_map(biosample, :biosample, :assembly)
    metadata[:ncbi_asm] = asm.to_s unless asm.nil?
    get_type_status_ncbi_asm metadata
  end

  def get_type_status_ncbi_asm(metadata)
    from_type = nil

    # Try first from previously pulled NCBI metadata
    if metadata[:ncbi_dataset]
      from_type = metadata.dig(
        :ncbi_dataset, :type_material, :type_display_text
      )
    else
      # Otherwise, check Assembly JSON document
      return metadata if ncbi_asm_json_doc.nil?

      metadata[:suspect] = (ncbi_asm_json_doc['exclfromrefseq'] || [])
      metadata[:suspect] = nil if metadata[:suspect].empty?
      return metadata if metadata[:is_type] # If predefined, as in SeqCode

      from_type = ncbi_asm_json_doc['from_type']
      from_type = ncbi_asm_json_doc['fromtype'] if from_type.nil?
    end

    case from_type
    when nil
      # Do nothing
    when ''
      metadata[:is_type] = false
      metadata[:is_ref_type] = false
    when 'assembly from reference material', 'assembly designated as reftype'
      metadata[:is_type] = false
      metadata[:is_ref_type] = true
      metadata[:type_rel] = from_type
    else
      metadata[:is_type] = true
      metadata[:type_rel] = from_type
    end
    MiGA.DEBUG "Got type: #{from_type}"
    metadata
  end

  def save_assembly_to(project, name, udb)
    dir = MiGA::Dataset.RESULT_DIRS[:assembly]
    base = "#{project.path}/data/#{dir}/#{name}"
    l_ctg = "#{base}.LargeContigs.fna"
    a_ctg = "#{base}.AllContigs.fna"
    File.open("#{base}.start", 'w') { |ofh| ofh.puts Time.now.to_s }
    if udb[:format] == :fasta_gz
      l_ctg_gz = "#{l_ctg}.gz"
      download(l_ctg_gz)
      self.class.run_cmd(['gzip', '-f', '-d', l_ctg_gz])
    else
      download(l_ctg)
    end
    File.unlink(a_ctg) if File.exist? a_ctg
    File.open("#{base}.done", 'w') { |ofh| ofh.puts Time.now.to_s }
  end
end
