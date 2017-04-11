# @package MiGA
# @license Artistic-2.0

require "restclient"
require "open-uri"

##
# MiGA representation of datasets with data in remote locations.
class MiGA::RemoteDataset < MiGA::MiGA
  # Class-level

  @@_EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
  ##
  # Structure of the different database Universes or containers. The structure
  # is a Hash with universe names as keys as Symbol and values being a Hash with
  # supported keys as Symbol:
  # - +:dbs+ => Hash with keys being the database name and the values a Hash of
  #   properties such as +stage+, +format+, and +map_to+.
  # - +url+ => Pattern of the URL where the data can be obtained, where +%1$s+
  #   is the name of the database, +%2$s+ is the IDs, and +%3$s+ is format.
  # - +method+ => Method used to query the URL. Only +:rest+ is currently
  #   supported.
  # - +map_to_universe+ => Universe where results map to. Currently unsupported.
  def self.UNIVERSE ; @@UNIVERSE ; end
  @@UNIVERSE = {
    web:{
      dbs: {
        assembly:{stage: :assembly, format: :fasta},
        assembly_gz:{stage: :assembly, format: :fasta_gz}
      },
      url: "%2$s",
      method: :net
    },
    ebi:{
      dbs: { embl:{stage: :assembly, format: :fasta} },
      url: "http://www.ebi.ac.uk/Tools/dbfetch/dbfetch/%1$s/%2$s/%3$s",
      method: :rest
    },
    ncbi:{
      dbs: { nuccore:{stage: :assembly, format: :fasta} },
      url: "#{@@_EUTILS}efetch.fcgi?db=%1$s&id=%2$s&rettype=%3$s&retmode=text",
      method: :rest
    },
    ncbi_map:{
      dbs: { assembly:{map_to: :nuccore, format: :text} },
        # FIXME ncbi_map is intended to do internal NCBI mapping between
        # databases.
      url: "#{@@_EUTILS}elink.fcgi?dbfrom=%1$s&id=%2$s&db=%3$s - - - - -",
      method: :rest,
      map_to_universe: :ncbi
    }
  }

  ##
  # Download data from the +universe+ in the database +db+ with IDs +ids+ and
  # in +format+. If passed, it saves the result in +file+. Returns String.
  def self.download(universe, db, ids, format, file=nil)
    ids = [ids] unless ids.is_a? Array
    case @@UNIVERSE[universe][:method]
    when :rest
      map_to = @@UNIVERSE[universe][:dbs][db].nil? ? nil :
        @@UNIVERSE[universe][:dbs][db][:map_to]
      url = sprintf @@UNIVERSE[universe][:url],
        db, ids.join(","), format, map_to
      response = RestClient::Request.execute(method: :get, url:url, timeout:600)
      raise "Unable to reach #{universe} client, error code " +
        "#{response.code}." unless response.code == 200
      doc = response.to_s
    when :net
      url = sprintf @@UNIVERSE[universe][:url],db,ids.join(","),format,map_to
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
    end
    unless file.nil?
      ofh = File.open(file, "w")
      ofh.print doc
      ofh.close
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
    name = ids.join("_").miga_name if name.nil?
    project = MiGA::Project.new(project) if project.is_a? String
    raise "Dataset #{name} exists in the project, aborting..." if
      MiGA::Dataset.exist?(project, name)
    metadata = get_metadata(metadata)
    case @@UNIVERSE[universe][:dbs][db][:stage]
    when :assembly
      dir = MiGA::Dataset.RESULT_DIRS[:assembly]
      base = "#{project.path}/data/#{dir}/#{name}"
      File.open("#{base}.start", "w") { |ofh| ofh.puts Time.now.to_s }
      if @@UNIVERSE[universe][:dbs][db][:format] == :fasta_gz
        download("#{base}.LargeContigs.fna.gz")
        system("gzip -d #{base}.LargeContigs.fna.gz")
      else
        download("#{base}.LargeContigs.fna")
      end
      File.symlink(
        File.basename("#{base}.LargeContigs.fna"), "#{base}.AllContigs.fna")
      File.open("#{base}.done", "w") { |ofh| ofh.puts Time.now.to_s }
    else
      raise "Unexpected error: Unsupported result for database #{db}."
    end
    dataset = MiGA::Dataset.new(project, name, is_ref, metadata)
    project.add_dataset(dataset.name)
    result = dataset.add_result(@@UNIVERSE[universe][:dbs][db][:stage],
      true, is_clean:true)
    raise "Empty dataset created: seed result was not added due to "+
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
