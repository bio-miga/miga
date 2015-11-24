#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Nov-24-2015
#

require 'miga/metadata'
require 'miga/project'
require 'miga/result'

module MiGA
   class Dataset
      # Class
      @@RESULT_DIRS = {
	 # Preprocessing
	 raw_reads: "01.raw_reads", trimmed_reads: "02.trimmed_reads",
	 read_quality: "03.read_quality", trimmed_fasta: "04.trimmed_fasta",
	 assembly: "05.assembly", cds: "06.cds",
	 # Annotation
	 essential_genes: "07.annotation/01.function/01.essential",
	 ssu: "07.annotation/01.function/02.ssu",
	 mytaxa: "07.annotation/02.taxonomy/01.mytaxa",
	 mytaxa_scan: "07.annotation/03.qa/02.mytaxa_scan",
	 # Mapping
	 mapping_on_contigs: "08.mapping/01.read-ctg",
	 mapping_on_genes: "08.mapping/02.read-gene",
	 # Distances (for single-species datasets)
	 distances: "09.distances"
      }
      @@KNOWN_TYPES = {
         genome: {description: "The genome from an isolate.", multi: false},
	 metagenome: {description: "A metagenome (excluding viromes).",
	    multi: true},
	 virome: {description: "A viral metagenome.", multi: true},
	 scgenome: {description: "A genome from a single cell.", multi: false},
	 popgenome: {description: "The genome of a population (including " +
	    "microdiversity).", :multi=>false}
      }
      @@PREPROCESSING_TASKS = [:raw_reads, :trimmed_reads, :read_quality,
	 :trimmed_fasta, :assembly, :cds, :essential_genes, :ssu, :mytaxa,
	 :mytaxa_scan, :distances]
      @@ONLY_MULTI_TASKS = [:mytaxa]
      @@ONLY_NONMULTI_TASKS = [:mytaxa_scan, :distances]
      def self.PREPROCESSING_TASKS ; @@PREPROCESSING_TASKS ; end
      def self.RESULT_DIRS ; @@RESULT_DIRS end
      def self.KNOWN_TYPES ; @@KNOWN_TYPES end
      def self.exist?(project, name)
	 File.exist? project.path + "/metadata/" + name + ".json"
      end
      def self.INFO_FIELDS
	 %w(name created updated type ref user description comments)
      end
      # Instance
      attr_reader :project, :name, :metadata
      def initialize(project, name, is_ref=true, metadata={})
	 abort "Invalid name '#{name}', please use only alphanumerics and " +
	    "underscores." if name !~ /^[A-Za-z0-9_]+$/
	 @project = project
	 @name = name
	 metadata[:ref] = is_ref
	 @metadata = Metadata.new(self.project.path + "/metadata/" + self.name +
	    ".json", metadata)
      end
      def save
	 self.metadata[:type] = :metagenome if !self.metadata[:tax].nil? and
	    !self.metadata[:tax][:ns].nil? and
	    self.metadata[:tax][:ns]=="COMMUNITY"
	 self.metadata.save
	 self.load
      end
      def load
         # Nothing here...
      end
      def remove!
         self.results.each{ |r| r.remove! }
	 self.metadata.remove!
      end
      def info()
	 Dataset.INFO_FIELDS.map do |k|
	    (k=="name") ? self.name : self.metadata[k.to_sym]
	 end
      end
      def is_ref?() !!self.metadata[:ref] end
      def is_multi?
	 return false if self.metadata[:type].nil?
	 return @@KNOWN_TYPES[self.metadata[:type]][:multi]
      end
      def is_nonmulti?
	 return false if self.metadata[:type].nil?
	 return !@@KNOWN_TYPES[self.metadata[:type]][:multi]
      end
      def result(name)
	 return nil if @@RESULT_DIRS[name.to_sym].nil?
	 Result.load(self.project.path + "/data/" + @@RESULT_DIRS[name.to_sym] +
	    "/" + self.name + ".json")
      end
      def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.compact end
      def each_result(&blk)
         @@RESULT_DIRS.keys.each do |k|
	    v = self.result k
	    blk.call(k,v) unless v.nil?
	 end
      end
      def add_result result_type
	 return nil if @@RESULT_DIRS[result_type].nil?
	 base = self.project.path + "/data/" + @@RESULT_DIRS[result_type] +
	    "/" + self.name
	 return nil unless File.exist? base + ".done"
	 r = nil
	 case result_type
	 when :raw_reads
	    return nil unless
	       File.exist? base + ".1.fastq" or
	       File.exist? base + ".1.fastq.gz"
	    r = Result.new base + ".json"
	    r.data[:gz] = File.exist?(base + ".1.fastq.gz")
	    if File.exist? base + ".2.fastq" + (r.data[:gz] ? ".gz" : "")
	       r.data[:files] = {
		  pair1: self.name + ".1.fastq" + (r.data[:gz] ? ".gz" : ""),
		  pair2: self.name + ".2.fastq" + (r.data[:gz] ? ".gz" : "")}
	    else
	       r.data[:files] = {
		  single: self.name + ".1.fastq" + (r.data[:gz] ? ".gz" : "")}
	    end
	 when :trimmed_reads
	    return nil unless
	       File.exist?(base + ".1.clipped.fastq") or
	       File.exist?(base + ".1.clipped.fastq.gz")
	    r = Result.new base + ".json"
	    r.data[:gz] = File.exist?(base + ".1.clipped.fastq.gz")
	    r.data[:files] = {}
	    if File.exist? base + ".2.clipped.fastq" + (r.data[:gz] ? ".gz":"")
	       r.data[:files][:pair1] =
		  self.name + ".1.clipped.fastq" + (r.data[:gz] ? ".gz" : "")
	       r.data[:files][:pair2] =
		  self.name + ".2.clipped.fastq" + (r.data[:gz] ? ".gz" : "")
	       r.data[:files][:single] =
		  self.name + ".1.clipped.single.fastq" +
		  (r.data[:gz] ? ".gz" : "")
	    else
	       r.data[:files][:single] =
		  self.name + ".1.clipped.fastq" + (r.data[:gz] ? ".gz" : "")
	    end
	    self.add_result :raw_reads #-> Post gunzip (if any)
	 when :read_quality
	    return nil unless
	       Dir.exist?(base + ".solexaqa") and
	       Dir.exist?(base + ".fastqc")
	    r = Result.new base + ".json"
	    r.data[:files] = {
	       solexaqa: self.name + ".solexaqa",
	       fastqc: self.name + ".fastqc"}
	    self.add_result :trimmed_reads #-> Post cleaning
	 when :trimmed_fasta
	    return nil unless
	       File.exist?(base + ".CoupledReads.fa") or
	       File.exist?(base + ".SingleReads.fa")
	    r = Result.new base + ".json"
	    if File.exist?(base + ".CoupledReads.fa")
	       r.data[:files] = {
		  coupled: self.name + ".CoupledReads.fa",
		  pair1: self.name + ".1.fasta.gz",
		  pair2: self.name + ".2.fasta.gz",
		  single: self.name + ".SingleReads.fa.gz"}
	    else
	       r.data[:files] = {
		  single: self.name + ".SingleReads.fa"}
	    end
	    self.add_result :raw_reads #-> Post gzip
	 when :assembly
	    return nil unless
	       File.exist?(base + ".LargeContigs.fna")
	    r = Result.new base + ".json"
	    r.data[:files] = {largecontigs: self.name + ".LargeContigs.fna"}
	    r.data[:files][:allcontigs] = self.name + ".AllContigs.fna" if
	       File.exist?(base + ".AllContigs.fna")
	 when :cds
	    return nil unless
	       File.exist?(base + ".faa") and
	       File.exist?(base + ".fna")
	    r = Result.new base + ".json"
	    r.data[:files] = {
	       proteins: self.name + ".faa",
	       genes: self.name + ".fna"}
	    r.data[:files][:gff2] = self.name + ".gff2.gz" if
	       File.exist? self.name + ".gff2.gz"
	    r.data[:files][:gff3] = self.name + ".gff3.gz" if
	       File.exist? self.name + ".gff3.gz"
	    r.data[:files][:tab] = self.name + ".tab.gz" if
	       File.exist? self.name + ".tab.gz"
	 when :essential_genes
	    return nil unless
	       File.exist?(base + ".ess.faa") and
	       Dir.exist?(base + ".ess") and
	       File.exist?(base + ".ess/log")
	    r = Result.new base + ".json"
	    r.data[:files] = {
	       ess_genes: self.name + ".ess.faa",
	       collection: self.name + ".ess",
	       report: self.name + ".ess/log"}
	 when :ssu
	    return nil unless
	       File.exist?(base + ".ssu.fa") or
	       File.exist?(base + ".ssu.fa.gz")
	    r = Result.new base + ".json"
	    r.data[:gz] = File.exist?(base + ".ssu.fa.gz")
	    r.data[:files] = {
	       longest_ssu_gene: self.name + ".ssu.fa" +
	       (r.data[:gz] ? ".gz" : "")}
	    r.data[:files][:gff] = self.name + ".ssu.gff" if
	       File.exist?(base + ".ssu.gff")
	    r.data[:files][:gff] = self.name + ".ssu.gff.gz" if
	       File.exist?(base + ".ssu.gff.gz")
	    r.data[:files][:all_ssu_genes] = self.name + ".ssu.all.fa" if
	       File.exist?(base + ".ssu.all.fa")
	    r.data[:files][:all_ssu_genes] = self.name + ".ssu.all.fa.gz" if
	       File.exist?(base + ".ssu.all.fa.gz")
	 when :mytaxa
	    if !self.metadata[:type].nil? and
		  Dataset.KNOWN_TYPES[self.metadata[:type]][:multi]
	       return nil unless File.exist?(base + ".mytaxa")
	       r = Result.new base + ".json"
	       r.data[:files] = {mytaxa: self.name + ".mytaxa"}
	       r.data[:gz] = File.exist?(base + ".mytaxain.gz")
	       r.data[:files][:blast] =
		  self.name + ".blast" + (r.data[:gz] ? ".gz" : "") if
		  File.exist?(base + ".blast" + (r.data[:gz] ? ".gz" : ""))
	       r.data[:files][:mytaxain] =
		  self.name + ".mytaxain" + (r.data[:gz] ? ".gz" : "") if
		  File.exist?(base + ".mytaxain" + (r.data[:gz] ? ".gz" : ""))
	    else
	       r = Result.new base + ".json"
	       r.data[:files] = {}
	    end
	 when :mytaxa_scan
	    if !self.metadata[:type].nil? and
		  !Dataset.KNOWN_TYPES[self.metadata[:type]][:multi]
	       return nil unless
		  File.exists?(base+".pdf") and
		  File.exist?(base+".wintax") and
		  File.exist?(base+".mytaxa") and
		  Dir.exist?(base+".reg")
	       r = Result.new base + ".json"
	       r.data[:files] = {
		  mytaxa: self.name + ".mytaxa",
		  wintax: self.name + ".wintax",
		  report: self.name + ".pdf",
		  regions: self.name + ".reg"}
	       r.data[:files][:gene_ids] =
		  self.name + ".wintax.genes" if
		  File.exist?(base + ".wintax.genes")
	       r.data[:files][:region_ids] =
		  self.name + ".wintax.regions" if
		  File.exist?(base + ".wintax.regions")
	       r.data[:files][:blast] =
		  self.name + ".blast.gz" if
		  File.exist?(base + ".blast.gz")
	       r.data[:files][:mytaxain] =
		  self.name + ".mytaxain.gz" if
		  File.exist?(base + ".mytaxain.gz")
	    else
	       r = Result.new base + ".json"
	       r.data[:files] = {}
	    end
	 when :distances
	    if !self.metadata[:type].nil? and
		  !Dataset.KNOWN_TYPES[self.metadata[:type]][:multi]
	       pref = self.project.path + "/data/" + @@RESULT_DIRS[result_type]
	       if is_ref?
		  return nil unless
		     File.exist?(pref + "/01.haai/" + self.name + ".db")
	       else
		  return nil unless
		     File.exist?(pref + "/02.aai/" + self.name + ".db")
	       end
	       r = Result.new base + ".json"
	       r.data[:files] = {}
	       r.data[:files][:haai_db] =
		  "01.haai/" + self.name + ".db" if
		  File.exist?(pref + "/01.haai/" + self.name + ".db")
	       r.data[:files][:aai_db] =
		  "02.aai/" + self.name + ".db" if
		  File.exist?(pref + "/02.aai/" + self.name + ".db")
	       r.data[:files][:ani_db] =
		  "03.ani/"  + self.name + ".db" if
		  File.exist?(pref + "/03.ani/" + self.name + ".db")
	    else
	       r = Result.new base + ".json"
	       r.data[:files] = {}
	    end
	 end
	 r.save
	 r
      end # def add_result
      def first_preprocessing
	 @@PREPROCESSING_TASKS.find{ |t| not self.add_result(t).nil? }
      end
      def next_preprocessing
         after_first = false
	 first = self.first_preprocessing
	 return nil if first.nil?
	 @@PREPROCESSING_TASKS.each do |t|
	    next if @@ONLY_MULTI_TASKS.include?(t) and not self.is_multi?
	    next if @@ONLY_NONMULTI_TASKS.include?(t) and not self.is_nonmulti?
	    return t if after_first and self.add_result(t).nil?
	    after_first = (after_first or (t==first))
	 end
	 nil
      end
      def done_preprocessing?
	 !self.first_preprocessing.nil? and self.next_preprocessing.nil?
      end
      def profile_advance
         if self.first_preprocessing.nil?
	    adv = Array.new(@@PREPROCESSING_TASKS.size, 0)
	 else
	    adv = []
	    state = 0
	    first_task = self.first_preprocessing
	    next_task = self.next_preprocessing
	    @@PREPROCESSING_TASKS.each do |task|
	       state = 1 if first_task==task
	       state = 2 if !next_task.nil? and next_task==task
	       adv << state
	    end
	 end
	 adv
      end
   end # class Dataset
end # module MiGA

