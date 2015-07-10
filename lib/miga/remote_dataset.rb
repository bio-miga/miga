#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jul-10-2015
#

require 'restclient'

module MiGA
   class RemoteDataset
      # Class
      @@UNIVERSE = {
	 ebi:{
	    dbs: { embl:{stage: :assembly, format: :fasta} },
	    url: "http://www.ebi.ac.uk/Tools/dbfetch/dbfetch/%1$s/%2$s/%3$s",
	    method: :rest
	 }
      }
      def self.UNIVERSE ; @@UNIVERSE ; end
      def self.download(universe, db, ids, format, file=nil)
	 ids = [ids] unless ids.is_a? Array
	 case @@UNIVERSE[universe][:method]
	 when :rest
	    url = sprintf @@UNIVERSE[universe][:url], db, ids.join(","), format
	    response = RestClient::Request.execute(:method=>:get,  :url=>url, :timeout=>600)
	    raise "Unable to reach #{universe} client, error code #{response.code}." unless response.code == 200
	    doc = response.to_s
	 else
	    raise "Unexpected error: Unsupported download method for Universe #{universe}."
	 end
	 unless file.nil?
	    ofh = File.open(file, "w")
	    ofh.print doc
	    ofh.close
	 end
	 doc
      end
      # Instance
      attr_reader :universe, :db, :ids
      def initialize(ids, db, universe)
	 ids = [ids] unless ids.is_a? Array
	 @ids = (ids.is_a?(Array) ? ids : [ids])
	 @db = db.to_sym
	 @universe = universe.to_sym
	 raise "Unknown Universe: #{@universe}. Try one of: #{@@UNIVERSE.keys}" unless @@UNIVERSE.keys.include? @universe
	 raise "Unknown Database: #{@db}. Try one of: #{@@UNIVERSE[@universe][:dbs]}" unless @@UNIVERSE[@universe][:dbs].include? @db
      end
      def save_to(project, name=nil, is_ref=true, metadata={})
	 name = ids.join("_").miga_name if name.nil?
	 project = Project.new(project) if project.is_a? String
	 raise "Dataset #{name} exists in the project, aborting..." if Dataset.exist?(project, name)
	 metadata = get_metadata(metadata)
	 case @@UNIVERSE[universe][:dbs][db][:stage]
	 when :assembly
	    base = project.path + "/data/" + Dataset.RESULT_DIRS[:assembly] + "/" + name
	    ofh = File.open("#{base}.start", "w")
	    ofh.puts Time.now.to_s
	    ofh.close
	    download("#{base}.LargeContigs.fna")
	    File.symlink("#{base}.LargeContigs.fna", "#{base}.AllContigs.fna")
	    ofh = File.open("#{base}.done", "w")
	    ofh.puts Time.now.to_s
	    ofh.close
	 else
	    raise "Unexpected error: Unsupported result for database #{db}."
	 end
	 dataset = Dataset.new(project, name, is_ref, metadata)
	 project.add_dataset(dataset.name)
	 result = dataset.add_result @@UNIVERSE[universe][:dbs][db][:stage]
	 raise "Empty dataset created: seed result was not added due to incomplete files." if result.nil?
	 dataset
      end
      def get_metadata(metadata={})
	 case universe
	 when :ebi
	    # Get taxonomy
	    metadata[:tax] = get_ncbi_taxonomy
	 end
	 metadata
      end
      def download(file)
	 RemoteDataset.download(universe, db, ids, @@UNIVERSE[universe][:dbs][db][:format], file)
      end
      def get_ncbi_taxid
	 case universe
	 when :ebi
	    doc = RemoteDataset.download(universe, db, ids, :annot).split(/\n/)
	    ln = doc.grep(/^FT\s+\/db_xref="taxon:/).first
	    ln = doc.grep(/^OX\s+NCBI_TaxID=/).first if ln.nil?
	    return nil if ln.nil?
	    ln.sub!(/.*(?:"taxon:|NCBI_TaxID=)(\d+)["; ].*/, "\\1")
	    return nil unless ln =~ /^\d+$/
	    ln
	 else
	    raise "I don't know how to extract ncbi_taxids from #{universe}."
	 end
      end
      def get_ncbi_taxonomy
	 lineage = {}
	 tax_id = get_ncbi_taxid
	 loop do
	    break if tax_id.nil? or %w{0 1}.include? tax_id
	    doc = RemoteDataset.download(:ebi, :taxonomy, tax_id, "")
	    name = (doc.scan(/SCIENTIFIC NAME\s+:\s+(.+)/).first||[]).first
	    rank = (doc.scan(/RANK\s+:\s+(.+)/).first||[]).first
	    rank = "dataset" if lineage.empty? and rank=="no rank"
	    lineage[rank] = name unless rank.nil?
	    tax_id = (doc.scan(/PARENT ID\s+:\s+(.+)/).first||[]).first
	 end
	 Taxonomy.new(lineage)
      end
   end
end

