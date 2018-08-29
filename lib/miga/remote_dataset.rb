# @package MiGA
# @license Artistic-2.0

require 'miga/remote_dataset/base'

##
# MiGA representation of datasets with data in remote locations.
class MiGA::RemoteDataset < MiGA::MiGA

  include MiGA::RemoteDataset::Base

  # Class-level

  ##
  # Download data from the +universe+ in the database +db+ with IDs +ids+ and
  # in +format+. If passed, it saves the result in +file+. Returns String.
  def self.download(universe, db, ids, format, file=nil)
    ids = [ids] unless ids.is_a? Array
    case @@UNIVERSE[universe][:method]
    when :rest
      doc = download_rest(universe, db, ids, format)
    when :net
      doc = download_net(universe, db, ids, format)
    end
    unless file.nil?
      ofh = File.open(file, "w")
      ofh.print doc
      ofh.close
    end
    doc
  end

  ##
  # Download data using a REST method from the +universe+ in the database +db+
  # with IDs +ids+ and in +format+. Returns the doc as String.
  def self.download_rest(universe, db, ids, format)
    u = @@UNIVERSE[universe]
    map_to = u[:dbs][db].nil? ? nil : u[:dbs][db][:map_to]
    url = sprintf(u[:url], db, ids.join(","), format, map_to)
    response = RestClient::Request.execute(method: :get, url:url, timeout:600)
    unless response.code == 200
      raise "Unable to reach #{universe} client, error code #{response.code}."
    end
    response.to_s
  end
  
  ##
  # Download data using a GET request from the +universe+ in the database +db+
  # with IDs +ids+ and in +format+. Returns the doc as String.
  def self.download_net(universe, db, ids, format)
    u = @@UNIVERSE[universe]
    map_to = u[:dbs][db].nil? ? nil : u[:dbs][db][:map_to]
    url = sprintf(u[:url], db, ids.join(","), format, map_to)
    doc = ""
    @timeout_try = 0
    begin
      open(url) { |f| doc = f.read }
    rescue Net::ReadTimeout
      @timeout_try += 1
      if @timeout_try > 3 ; raise Net::ReadTimeout
      else ; retry
      end
    end
    doc
  end

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
    raise "Unknown Universe: #{@universe}. Try one of: "+
      "#{@@UNIVERSE.keys}" unless @@UNIVERSE.keys.include? @universe
    raise "Unknown Database: #{@db}. Try one of: "+
      "#{@@UNIVERSE[@universe][:dbs]}" unless
      @@UNIVERSE[@universe][:dbs].include? @db
    # FIXME Part of the +map_to+ support:
    #unless @@UNIVERSE[@universe][:dbs][@db][:map_to].nil?
    #  MiGA::RemoteDataset.download
    #end
  end

  ##
  # Save dataset to the MiGA::Project +project+ identified with +name+. +is_ref+
  # indicates if it should be a reference dataset, and contains +metadata+.
  def save_to(project, name=nil, is_ref=true, metadata={})
    name ||= ids.join("_").miga_name
    project = MiGA::Project.new(project) if project.is_a? String
    if MiGA::Dataset.exist?(project, name)
      raise "Dataset #{name} exists in the project, aborting..."
    end
    metadata = get_metadata(metadata)
    udb = @@UNIVERSE[universe][:dbs][db]
    metadata["#{universe}_#{db}"] = ids.join(",")
    case udb[:stage]
    when :assembly
      dir = MiGA::Dataset.RESULT_DIRS[:assembly]
      base = "#{project.path}/data/#{dir}/#{name}"
      l_ctg = "#{base}.LargeContigs.fna"
      a_ctg = "#{base}.AllContigs.fna"
      File.open("#{base}.start", "w") { |ofh| ofh.puts Time.now.to_s }
      if udb[:format] == :fasta_gz
        download "#{l_ctg}.gz"
        system "gzip -d '#{l_ctg}.gz'"
      else
        download l_ctg
      end
      File.unlink(a_ctg) if File.exist? a_ctg
      File.symlink(File.basename(l_ctg), a_ctg)
      File.open("#{base}.done", "w") { |ofh| ofh.puts Time.now.to_s }
    else
      raise "Unexpected error: Unsupported result for database #{db}."
    end
    dataset = MiGA::Dataset.new(project, name, is_ref, metadata)
    project.add_dataset(dataset.name)
    result = dataset.add_result(udb[:stage], true, is_clean:true)
    raise "Empty dataset created: seed result was not added due to " +
      "incomplete files." if result.nil?
    result.clean!
    result.save
    dataset
  end

  ##
  # Get metadata from the remote location.
  def get_metadata(metadata={})
    case universe
    when :ebi, :ncbi
      # Get taxonomy
      metadata[:tax] = get_ncbi_taxonomy
    end
    metadata
  end

  ##
  # Download data into +file+.
  def download(file)
    MiGA::RemoteDataset.download(universe, db, ids,
      @@UNIVERSE[universe][:dbs][db][:format], file)
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
    while !(tax_id.nil? or %w{0 1}.include? tax_id)
      doc = MiGA::RemoteDataset.download(:ebi, :taxonomy, tax_id, "")
      name = doc.scan(/SCIENTIFIC NAME\s+:\s+(.+)/).first.to_a.first
      rank = doc.scan(/RANK\s+:\s+(.+)/).first.to_a.first
      rank = "dataset" if lineage.empty? and rank=="no rank"
      lineage[rank] = name unless rank.nil?
      tax_id = doc.scan(/PARENT ID\s+:\s+(.+)/).first.to_a.first
    end
    MiGA::Taxonomy.new(lineage)
  end

  private
    
    def get_ncbi_taxid_from_ncbi
      doc = MiGA::RemoteDataset.download(universe, db, ids, :gb).split(/\n/)
      ln = doc.grep(/^\s+\/db_xref="taxon:/).first
      return nil if ln.nil?
      ln.sub!(/.*(?:"taxon:)(\d+)["; ].*/, "\\1")
      return nil unless ln =~ /^\d+$/
      ln
    end

    def get_ncbi_taxid_from_ebi
      doc = MiGA::RemoteDataset.download(universe, db, ids, :annot).split(/\n/)
      ln = doc.grep(/^FT\s+\/db_xref="taxon:/).first
      ln = doc.grep(/^OX\s+NCBI_TaxID=/).first if ln.nil?
      return nil if ln.nil?
      ln.sub!(/.*(?:"taxon:|NCBI_TaxID=)(\d+)["; ].*/, "\\1")
      return nil unless ln =~ /^\d+$/
      ln
    end

end
