#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jun-08-2015
#

require 'miga/dataset'

module MiGA
   class Project
      # Class
      @@FOLDERS = %w(data metadata daemon)
      @@DATA_FOLDERS = %w(
	 01.raw_reads 02.trimmed_reads 03.read_quality 04.trimmed_fasta 05.assembly 06.cds
	 07.annotation 07.annotation/01.function 07.annotation/02.taxonomy
	 07.annotation/01.function/01.essential
	 07.annotation/03.qa 07.annotation/03.qa/01.checkm
	 08.mapping 08.mapping/01.read-ctg 08.mapping/02.read-gene
	 09.distances 09.distances/01.haai 09.distances/02.aai 09.distances/03.ani 09.distances/04.ssu
	 10.clades 10.clades/01.find 10.clades/02.ani 10.clades/03.ogs 10.clades/04.phylogeny
	 10.clades/04.phylogeny/01.essential 10.clades/04.phylogeny/02.core 10.clades/05.metadata)
      @@RESULT_DIRS = {
	 # Distances
	 :haai_distances=>"09.distances/01.haai",
	 :aai_distances=>"09.distances/02.aai",
	 :ani_distances=>"09.distances/03.ani",
	 #:ssu_distances=>"09.distances/04.ssu",
	 # Clade identification
	 :clade_finding=>"10.clades/01.find",
	 # Clade analysis
	 :subclades=>"10.clades/02.ani",
	 :ogs=>"10.clades/03.ogs",
	 :ess_phylogeny=>"10.clades/04.phylogeny/01.essential",
	 :core_phylogeny=>"10.clades/04.phylogeny/02.core",
	 :clade_metadata=>"10.clades/05.metadata"
      }
      @@KNOWN_TYPES = {
	 :mixed=>{:description=>"Mixed collection of genomes, metagenomes, and viromes.", :single=>true, :multi=>true},
	 :genomes=>{:description=>"Collection of genomes.", :single=>true, :multi=>false},
	 :clade=>{:description=>"Collection of closely-related genomes (ANI ≤ 90%).", :single=>true, :multi=>false},
	 :metagenomes=>{:description=>"Collection of metagenomes and/or viromes.", :single=>false, :multi=>true}
      }
      @@DISTANCE_TASKS = [:haai_distances, :ani_distances, :aai_distances, :clade_finding]
      @@INCLADE_TASKS = [:subclades, :ogs, :ess_phylogeny, :core_phylogeny, :clade_metadata]
      def self.RESULT_DIRS() @@RESULT_DIRS end
      def self.KNOWN_TYPES() @@KNOWN_TYPES end
      def self.exist?(path)
	 Dir.exist?(path) and File.exist?(path + "/miga.project.json")
      end
      def self.load(path)
	 return nil unless Project.exist? path
	 Project.new path
      end
      # Instance
      attr_reader :path, :metadata, :datasets
      def initialize(path, update=false)
         raise "Impossible to create project in uninitialized MiGA." unless File.exist? "#{ENV["HOME"]}/.miga_rc" and File.exist? "#{ENV["HOME"]}/.miga_daemon.json"
	 @path = File.absolute_path(path)
	 self.create if update or !Project.exist? self.path
	 self.load if self.metadata.nil?
      end
      def create
	 Dir.mkdir self.path unless Dir.exist? self.path
	 @@FOLDERS.each{ |dir| Dir.mkdir self.path + "/" + dir unless Dir.exist? self.path + "/" + dir }
	 @@DATA_FOLDERS.each{ |dir| Dir.mkdir self.path + "/data/" + dir unless Dir.exist? self.path + "/data/" + dir }
	 @metadata = Metadata.new self.path + "/miga.project.json", {:datasets=>[], :name=>File.basename(self.path)}
	 FileUtils.cp ENV["HOME"] + "/.miga_daemon.json", self.path + "/daemon/daemon.json" unless File.exist? self.path + "/daemon/daemon.json"
	 self.save
      end
      def save
	 self.metadata.save
	 self.load
      end
      def load
	 @metadata = Metadata.load self.path + "/miga.project.json"
	 raise "Couldn't find project metadata at #{self.path}" if self.metadata.nil?
	 @datasets = self.metadata[:datasets].map{ |ds| Dataset.new self, ds }
      end
      def dataset(name)
	 name = name.miga_name
	 self.datasets.select{ |ds| ds.name==name }.first
      end
      def add_dataset(name)
	 self.metadata[:datasets] << name unless self.metadata[:datasets].include? name
	 self.save
	 self.dataset(name)
      end
      def unlink_dataset(name)
	 d = self.dataset name
	 return nil if d.nil?
	 self.metadata[:datasets].delete(name)
	 self.save
	 d
      end
      def result(name)
	 return nil if @@RESULT_DIRS[name.to_sym].nil?
	 Result.load self.path + "/data/" + @@RESULT_DIRS[name.to_sym] + "/result.json"
      end
      def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.reject{ |r| r.nil? } end
      def add_result result_type
	 return nil if @@RESULT_DIRS[result_type].nil?
	 base = self.path + "/data/" + @@RESULT_DIRS[result_type] + "/miga-project"
	 return nil unless File.exist? base + ".done"
	 r = nil
	 case result_type
	 when :haai_distances, :aai_distances, :ani_distances, :ssu_distances
	    return nil unless File.exist? base + ".Rdata" and File.exist? base + ".log" and (File.exist?(base + ".txt") or File.exist?(base + ".txt.gz"))
	    r = Result.new base + ".json"
	    r.data[:files] = {:rdata=>"miga-project.Rdata", :matrix=>"miga-project.txt", :log=>"miga-project.log"}
	    if File.exist? base + ".txt.gz"
	       r.data[:files][:matrix] += ".gz"
	       r.data[:gz] = true
	    end
	 end
	 r.save
	 r
      end
      def next_distances
	 @@DISTANCE_TASKS.find{ |t| self.add_result(t).nil? }
      end
      def next_inclade
         return nil unless self.metadata[:type]==:clade
	 @@INCLADE_TASKS.find{ |t| self.add_result(t).nil? }
      end
      def unregistered_datasets
	 datasets = []
	 Dataset.RESULT_DIRS.each do |res, dir|
	    Dir.entries(self.path + "/data/" + dir).each do |file|
	       next unless (file =~ /\.(fa|fna|faa|fasta|fastq|solexaqa|fastqc|gff[23]?|done)(\.gz)?$/)
	       m = /([^\.]+)/.match(file)
	       datasets << m[1] unless m.nil? or m[1] == "miga-project"
	    end
	 end
	 datasets.uniq - self.metadata[:datasets]
      end
      def done_preprocessing?() self.datasets.map{|ds| (not ds.is_ref?) or ds.done_preprocessing?}.all? end
   end
end

