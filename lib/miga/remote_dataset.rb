# @package MiGA
# @license Artistic-2.0

require 'miga/remote_dataset/download'

##
# MiGA representation of datasets with data in remote locations.
class MiGA::RemoteDataset < MiGA::MiGA
  include MiGA::RemoteDataset::Download

  # Instance-level

  ##
  # Universe of the dataset.
  attr_reader :universe
  # Database storing the dataset.
  attr_reader :db
  # Array of IDs of the entries composing the dataset.
  attr_reader :ids

  ##
  # Initialize MiGA::RemoteDataset with +ids+ in database +db+ from +universe+.
  def initialize(ids, db, universe)
    ids = [ids] unless ids.is_a? Array
    @ids = (ids.is_a?(Array) ? ids : [ids])
    @db = db.to_sym
    @universe = universe.to_sym
    @@UNIVERSE.keys.include?(@universe) or
      raise "Unknown Universe: #{@universe}. Try: #{@@UNIVERSE.keys}"
    @@UNIVERSE[@universe][:dbs].include?(@db) or
      raise "Unknown Database: #{@db}. Try: #{@@UNIVERSE[@universe][:dbs]}"
    # FIXME: Part of the +map_to+ support:
    # unless @@UNIVERSE[@universe][:dbs][@db][:map_to].nil?
    #   MiGA::RemoteDataset.download
    # end
  end

  ##
  # Save dataset to the MiGA::Project +project+ identified with +name+. +is_ref+
  # indicates if it should be a reference dataset, and contains +metadata+.
  def save_to(project, name = nil, is_ref = true, metadata = {})
    name ||= ids.join('_').miga_name
    project = MiGA::Project.new(project) if project.is_a? String
    MiGA::Dataset.exist?(project, name) and
      raise "Dataset #{name} exists in the project, aborting..."
    metadata = get_metadata(metadata)
    udb = @@UNIVERSE[universe][:dbs][db]
    metadata["#{universe}_#{db}"] = ids.join(',')
    respond_to?("save_#{udb[:stage]}_to", true) or
      raise "Unexpected error: Unsupported stage #{udb[:stage]} for #{db}."
    send "save_#{udb[:stage]}_to", project, name, udb
    dataset = MiGA::Dataset.new(project, name, is_ref, metadata)
    project.add_dataset(dataset.name)
    result = dataset.add_result(udb[:stage], true, is_clean: true)
    result.nil? and
      raise 'Empty dataset: seed result not added due to incomplete files.'
    result.clean!
    result.save
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
  def get_metadata(metadata = {})
    case universe
    when :ebi, :ncbi, :web
      # Get taxonomy
      metadata[:tax] = get_ncbi_taxonomy
    end
    metadata[:"#{universe}_#{db}"] = ids.join(",")
    metadata = get_type_status(metadata)
    metadata
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

  private

    def get_ncbi_taxid_from_web
      return nil unless metadata[:ncbi_asm]
      base_url = 'https://www.ncbi.nlm.nih.gov/assembly'
      doc = self.class.download_url(
        "#{base_url}/#{metadata[:ncbi_asm]}?report=xml&format=text")
      taxid = doc.scan(%r{&lt;Taxid&gt;(\S+)&lt;/Taxid&gt;}).first
      taxid.nil? ? taxid : taxid.first
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
      asm = self.class.ncbi_map(biosample,
        :biosample, :assembly)
      metadata[:ncbi_asm] = asm.to_s unless asm.nil?
      get_type_status_ncbi_asm metadata
    end

    def get_type_status_ncbi_asm(metadata)
      return metadata if metadata[:ncbi_asm].nil?
      doc = CGI.unescapeHTML(self.class.download(:web, :text,
        "https://www.ncbi.nlm.nih.gov/assembly/" \
          "#{metadata[:ncbi_asm]}?report=xml", :xml)).each_line
      from_type = doc.grep(%r{<FromType/?>}).first or return metadata
      if from_type =~ %r{<FromType/>}
        metadata[:is_type] = false
        metadata[:is_ref_type] = false
      elsif from_type =~ %r{<FromType>(.*)</FromType>}
        if $1 == 'assembly from reference material'
          metadata[:is_type] = false
          metadata[:is_ref_type] = true
        else
          metadata[:is_type] = true
        end
        metadata[:type_rel] = $1
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
