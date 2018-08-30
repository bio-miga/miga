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
  # IDs of the entries composing the dataset.
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
  # Get metadata from the remote location.
  def get_metadata(metadata = {})
    case universe
    when :ebi, :ncbi
      # Get taxonomy
      metadata[:tax] = get_ncbi_taxonomy
    end
    metadata
  end

  ##
  # Get NCBI Taxonomy ID.
  def get_ncbi_taxid
    send("get_ncbi_taxid_from_#{universe}")
  end

  ##
  # Get NCBI taxonomy as MiGA::Taxonomy.
  def get_ncbi_taxonomy
    lineage = {}
    tax_id = get_ncbi_taxid
    until [nil, '0', '1'].include? tax_id
      doc = MiGA::RemoteDataset.download(:ebi, :taxonomy, tax_id, '')
      name = doc.scan(/SCIENTIFIC NAME\s+:\s+(.+)/).first.to_a.first
      rank = doc.scan(/RANK\s+:\s+(.+)/).first.to_a.first
      rank = 'dataset' if lineage.empty? and rank == 'no rank'
      lineage[rank] = name unless rank.nil?
      tax_id = doc.scan(/PARENT ID\s+:\s+(.+)/).first.to_a.first
    end
    MiGA::Taxonomy.new(lineage)
  end

  private

    def get_ncbi_taxid_from_ncbi
      doc = MiGA::RemoteDataset.download(universe, db, ids, :gb).split(/\n/)
      ln = doc.grep(%r{^\s+/db_xref="taxon:}).first
      return nil if ln.nil?
      ln.sub!(/.*(?:"taxon:)(\d+)["; ].*/, '\\1')
      return nil unless ln =~ /^\d+$/
      ln
    end

    def get_ncbi_taxid_from_ebi
      doc = MiGA::RemoteDataset.download(universe, db, ids, :annot).split(/\n/)
      ln = doc.grep(%r{^FT\s+/db_xref="taxon:}).first
      ln = doc.grep(/^OX\s+NCBI_TaxID=/).first if ln.nil?
      return nil if ln.nil?
      ln.sub!(/.*(?:"taxon:|NCBI_TaxID=)(\d+)["; ].*/, '\\1')
      return nil unless ln =~ /^\d+$/
      ln
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
