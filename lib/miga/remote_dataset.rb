# @package MiGA
# @license Artistic-2.0

require 'miga/remote_dataset/download'

##
# MiGA representation of datasets with data in remote locations.
class MiGA::RemoteDataset < MiGA::MiGA
  include MiGA::RemoteDataset::Download

  # Class-level

  class << self
    def ncbi_asm_acc2id(acc)
      return acc if acc =~ /^\d+$/
      search_doc = JSON.parse download(:ncbi_search, :assembly, acc, :json)
      search_doc['esearchresult']['idlist'].first
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
    @metadata[:"#{universe}_#{db}"] = ids.join(",")
    @@UNIVERSE.keys.include?(@universe) or
      raise "Unknown Universe: #{@universe}. Try: #{@@UNIVERSE.keys}"
    @@UNIVERSE[@universe][:dbs].include?(@db) or
      raise "Unknown Database: #{@db}. Try: #{@@UNIVERSE[@universe][:dbs]}"
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
    metadata.each { |k,v| dataset.metadata[k] = v }
    dataset.save
  end

  ##
  # Get metadata from the remote location.
  def get_metadata(metadata_def = {})
    metadata_def.each { |k,v| @metadata[k] = v }
    case universe
    when :ebi, :ncbi, :web
      # Get taxonomy
      @metadata[:tax] = get_ncbi_taxonomy
    end
    @metadata = get_type_status(metadata)
  end

  ##
  # Get NCBI Taxonomy ID.
  def get_ncbi_taxid
    origin = (universe == :ncbi and db == :assembly) ? :web : universe
    send("get_ncbi_taxid_from_#{origin}")
  end

  ##
  # Get the type material status and return an (updated)
  # +metadata+ hash.
  def get_type_status(metadata)
    if metadata[:ncbi_asm]
      get_type_status_ncbi_asm metadata
    elsif metadata[:ncbi_nuccore]
      get_type_status_ncbi_nuccore metadata
    else
      metadata
    end
  end

  ##
  # Get NCBI taxonomy as MiGA::Taxonomy.
  def get_ncbi_taxonomy
    tax_id = get_ncbi_taxid
    return nil if tax_id.nil?
    lineage = {}
    doc = MiGA::RemoteDataset.download(:ncbi, :taxonomy, tax_id, :xml)
    doc.scan(%r{<Taxon>(.*?)</Taxon>}m).map(&:first).each do |i|
      name = i.scan(%r{<ScientificName>(.*)</ScientificName>}).first.to_a.first
      rank = i.scan(%r{<Rank>(.*)</Rank>}).first.to_a.first
      rank = nil if rank == 'no rank' or rank.empty?
      rank = 'dataset' if lineage.empty? and rank.nil?
      lineage[rank] = name unless rank.nil? or rank.nil?
    end
    MiGA::Taxonomy.new(lineage)
  end

  ##
  # Get the JSON document describing an NCBI assembly entry.
  def ncbi_asm_json_doc
    return @_ncbi_asm_json_doc unless @_ncbi_asm_json_doc.nil?
    metadata[:ncbi_asm] ||= ids.first if universe == :ncbi and db == :assembly
    return nil unless metadata[:ncbi_asm]
    ncbi_asm_id = self.class.ncbi_asm_acc2id metadata[:ncbi_asm]
    doc = JSON.parse(
      self.class.download(:ncbi_summary, :assembly, ncbi_asm_id, :json))
    @_ncbi_asm_json_doc = doc['result'][ doc['result']['uids'].first ]
  end


  private

    def get_ncbi_taxid_from_web
      return nil if ncbi_asm_json_doc.nil?
      ncbi_asm_json_doc['taxid']
    end

    def get_ncbi_taxid_from_ncbi
      doc = self.class.download(universe, db, ids, :gb).split(/\n/)
      ln = doc.grep(%r{^\s+/db_xref="taxon:}).first
      return nil if ln.nil?
      ln.sub!(/.*(?:"taxon:)(\d+)["; ].*/, '\\1')
      return nil unless ln =~ /^\d+$/
      ln
    end

    def get_ncbi_taxid_from_ebi
      doc = self.class.download(universe, db, ids, :annot).split(/\n/)
      ln = doc.grep(%r{^FT\s+/db_xref="taxon:}).first
      ln = doc.grep(/^OX\s+NCBI_TaxID=/).first if ln.nil?
      return nil if ln.nil?
      ln.sub!(/.*(?:"taxon:|NCBI_TaxID=)(\d+)["; ].*/, '\\1')
      return nil unless ln =~ /^\d+$/
      ln
    end

    def get_type_status_ncbi_nuccore(metadata)
      return metadata if metadata[:ncbi_nuccore].nil?
      biosample = self.class.ncbi_map(metadata[:ncbi_nuccore],
        :nuccore, :biosample)
      return metadata if biosample.nil?
      asm = self.class.ncbi_map(biosample, :biosample, :assembly)
      metadata[:ncbi_asm] = asm.to_s unless asm.nil?
      get_type_status_ncbi_asm metadata
    end

    def get_type_status_ncbi_asm(metadata)
      return metadata if ncbi_asm_json_doc.nil?
      from_type = ncbi_asm_json_doc['from_type']
      from_type = ncbi_asm_json_doc['fromtype'] if from_type.nil?
      case from_type
      when nil
        # Do nothing
      when ''
        metadata[:is_type] = false
        metadata[:is_ref_type] = false
      when 'assembly from reference material'
        metadata[:is_type] = false
        metadata[:is_ref_type] = true
        metadata[:type_rel] = from_type
      else
        metadata[:is_type] = true
        metadata[:type_rel] = from_type
      end
      metadata
    end

    def save_assembly_to(project, name, udb)
      dir = MiGA::Dataset.RESULT_DIRS[:assembly]
      base = "#{project.path}/data/#{dir}/#{name}"
      l_ctg = "#{base}.LargeContigs.fna"
      a_ctg = "#{base}.AllContigs.fna"
      File.open("#{base}.start", 'w') { |ofh| ofh.puts Time.now.to_s }
      if udb[:format] == :fasta_gz
        download "#{l_ctg}.gz"
        system "gzip -d '#{l_ctg}.gz'"
      else
        download l_ctg
      end
      File.unlink(a_ctg) if File.exist? a_ctg
      File.symlink(File.basename(l_ctg), a_ctg)
      File.open("#{base}.done", 'w') { |ofh| ofh.puts Time.now.to_s }
    end
end
