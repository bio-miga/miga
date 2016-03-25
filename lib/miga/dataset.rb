# @package MiGA
# @license artistic license 2.0

require "miga/metadata"
require "miga/project"
require "miga/result"

class MiGA::Dataset
  
  # Class-level

  ##
  # Directories containing the results from dataset-specific tasks.
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
  def self.RESULT_DIRS ; @@RESULT_DIRS end

  ##
  # Supported dataset types.
  @@KNOWN_TYPES = {
    genome: {description: "The genome from an isolate.", multi: false},
    metagenome: {description: "A metagenome (excluding viromes).",
      multi: true},
    virome: {description: "A viral metagenome.", multi: true},
    scgenome: {description: "A genome from a single cell.", multi: false},
    popgenome: {description: "The genome of a population (including " +
      "microdiversity).", :multi=>false}
  }
  def self.KNOWN_TYPES ; @@KNOWN_TYPES end

  ##
  # Tasks to be executed before project-wide tasks.
  @@PREPROCESSING_TASKS = [:raw_reads, :trimmed_reads, :read_quality,
    :trimmed_fasta, :assembly, :cds, :essential_genes, :ssu, :mytaxa,
    :mytaxa_scan, :distances]
  def self.PREPROCESSING_TASKS ; @@PREPROCESSING_TASKS ; end
  
  ##
  # Tasks to be excluded from query datasets.
  @@EXCLUDE_NOREF_TASKS = [:essential_genes, :mytaxa_scan]
  
  ##
  # Tasks to be executed only in datasets that are not multi-organism. These
  # tasks are ignored for multi-organism datasets or for unknown types.
  @@ONLY_NONMULTI_TASKS = [:mytaxa_scan, :distances]

  ##
  # Tasks to be executed only in datasets that are multi-organism. These
  # tasks are ignored for single-organism datasets or for unknwon types.
  @@ONLY_MULTI_TASKS = [:mytaxa]

  ##
  # Does the +project+ already have a dataset with that +name+?
  def self.exist?(project, name)
       File.exist? project.path + "/metadata/" + name + ".json"
  end

  ##
  # Standard fields of metadata for datasets.
  def self.INFO_FIELDS
       %w(name created updated type ref user description comments)
  end

  # Instance-level

  ##
  # Datasets are uniquely identified by +name+ within a +project+ of
  # class MiGA::Project, and contain +metadata+ of class MiGA::Metadata.
  attr_reader :project, :name, :metadata
  
  def initialize(project, name, is_ref=true, metadata={})
    abort "Invalid name '#{name}', please use only alphanumerics and " +
      "underscores." unless name.miga_name?
    @project = project
    @name = name
    metadata[:ref] = is_ref
    @metadata = MiGA::Metadata.new(project.path + "/metadata/" + name + ".json",
      metadata)
  end
  
  def save
    self.metadata[:type] = :metagenome if !metadata[:tax].nil? and
      !metadata[:tax][:ns].nil? and metadata[:tax][:ns]=="COMMUNITY"
    self.metadata.save
    self.load
  end
  
  def load
  end
  
  def remove!
    self.results.each{ |r| r.remove! }
    self.metadata.remove!
  end
  
  def info()
    MiGA::Dataset.INFO_FIELDS.map do |k|
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
  
  def result(k)
    return nil if @@RESULT_DIRS[k.to_sym].nil?
    MiGA::Result.load(project.path + "/data/" + @@RESULT_DIRS[k.to_sym] +
      "/" + name + ".json")
  end
  
  def results() @@RESULT_DIRS.keys.map{ |k| self.result k }.compact ; end
  
  def each_result(&blk)
    @@RESULT_DIRS.keys.each do |k|
      v = self.result k
      blk.call(k,v) unless v.nil?
    end
  end
  
  def add_result result_type
    return nil if @@RESULT_DIRS[result_type].nil?
    base = project.path + "/data/" + @@RESULT_DIRS[result_type] +
      "/" + name
    return nil unless File.exist? base + ".done"
    r = nil
    case result_type
    when :raw_reads
      return nil unless result_files_exist?(base, %w[.1.fastq])
      r = MiGA::Result.new base + ".json"
      r.data[:gz] = File.exist?(base + ".1.fastq.gz")
      if result_files_exist?(base, ".2.fastq")
        r.add_file :pair1, name + ".1.fastq"
        r.add_file :pair2, name + ".2.fastq"
      else
        r.add_file :single, name + ".1.fastq"
      end
    when :trimmed_reads
      return nil unless result_files_exist?(base, %w[.1.clipped.fastq])
      r = MiGA::Result.new base + ".json"
      r.data[:gz] = File.exist?(base + ".1.clipped.fastq.gz")
      if result_files_exist?(base, ".2.clipped.fastq")
        r.add_file :pair1, name + ".1.clipped.fastq"
        r.add_file :pair2, name + ".2.clipped.fastq"
      end
      r.add_file :single, name + ".1.clipped.single.fastq"
      add_result :raw_reads #-> Post gunzip (if any)
    when :read_quality
      return nil unless result_files_exist?(base, %w[.solexaqa .fastqc])
      r = MiGA::Result.new base + ".json"
      r.add_file :solexaqa, name + ".solexaqa"
      r.add_file :fastqc, name + ".fastqc"
      add_result :trimmed_reads #-> Post cleaning
    when :trimmed_fasta
      return nil unless
        result_files_exist?(base, %w[.CoupledReads.fa]) or
        result_files_exist?(base, %w[.SingleReads.fa])
      r = MiGA::Result.new base + ".json"
      if results_file_exist?(base, %w[.CoupledReads.fa"])
        r.add_file(:coupled, name + ".CoupledReads.fa")
        r.add_file(:pair1, name + ".1.fa")
        r.add_file(:pair2, name + ".2.fa")
      end
      r.add_file :single, name + ".SingleReads.fa"
      add_result :raw_reads #-> Post gzip
    when :assembly
      return nil unless result_files_exist?(base, %w[.LargeContigs.fna])
      r = MiGA::Result.new base + ".json"
      r.add_file(:largecontigs, name + ".LargeContigs.fna")
      r.add_file(:allcontigs, name + ".AllContigs.fna")
    when :cds
      return nil unless result_files_exist?(base, %w[.faa .fna])
      r = MiGA::Result.new base + ".json"
      r.add_file :proteins, name + ".faa"
      r.add_file :genes, name + ".fna"
      %w[gff2 gff3 tab].each do |ext|
        r.add_file ext, "#{name}.#{ext}"
      end
    when :essential_genes
      return nil unless result_files_exist?(base, %w[.ess.fa .ess .ess/log])
      r = MiGA::Result.new base + ".json"
      r.add_file :ess_genes, name + ".ess.faa"
      r.add_file :collection, name + ".ess"
      r.add_file :report, name + ".ess/log"
    when :ssu
      if result(:assembly).nil?
        r = MiGA::Result.new base + ".json"
      else
        return nil unless result_files_exist?(base, %w[.ssu.fa])
        r = MiGA::Result.new base + ".json"
        r.data[:gz] = File.exist?(base + ".ssu.fa.gz")
        r.add_file :longest_ssu_gene, name + ".ssu.fa"
        r.add_file :gff, name + ".ssu.gff"
        r.add_file :all_ssu_genes, name + ".ssu.all.fa"
      end
    when :mytaxa
      if is_multi?
        return nil unless result_files_exist?(base, %w[.mytaxa])
        r = MiGA::Result.new base + ".json"
        r.data[:gz] = File.exist?(base + ".mytaxain.gz")
        r.add_file :mytaxa, name + ".mytaxa"
        r.add_file :blast, name + ".blast"
        r.add_file :mytaxain, name + ".mytaxain"
      else
        r = MiGA::Result.new base + ".json"
        r.data[:files] = {}
      end
    when :mytaxa_scan
      if is_nonmulti?
        return nil unless
          result_files_exist?(base, %w[.pdf .wintax .mytaxa .reg])
        r = MiGA::Result.new base + ".json"
        r.add_file :mytaxa, name + ".mytaxa"
        r.add_file :wintax, name + ".wintax"
        r.add_file :report, name + ".pdf"
        r.add_file :regions, name + ".reg"
        r.add_file :gene_ids, name + ".wintax.genes"
        r.add_file :region_ids, name + ".wintax.regions"
        r.add_file :blast, name + ".blast"
        r.add_file :mytaxain, name + ".mytaxain"
      else
        r = MiGA::Result.new base + ".json"
        r.data[:files] = {}
      end
    when :distances
      if is_nonmulti?
        pref = project.path + "/data/" + @@RESULT_DIRS[result_type]
        if is_ref?
          return nil unless
            File.exist?(pref + "/01.haai/" + name + ".db")
        else
          return nil unless
            File.exist?(pref + "/02.aai/" + name + ".db")
        end
        r = MiGA::Result.new base + ".json"
        r.add_file :haai_db, "01.haai/" + name + ".db"
        r.add_file :aai_db, "02.aai/" + name + ".db"
        r.add_file :ani_db, "03.ani/" + name + ".db"
      else
        r = MiGA::Result.new base + ".json"
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
      next if @@EXCLUDE_NOREF_TASKS.include?(t) and not is_ref?
      next if @@ONLY_MULTI_TASKS.include?(t) and not is_multi?
      next if @@ONLY_NONMULTI_TASKS.include?(t) and not is_nonmulti?
      return t if after_first and add_result(t).nil?
      after_first = (after_first or (t==first))
       end
       nil
  end
  
  def done_preprocessing?
       !first_preprocessing.nil? and next_preprocessing.nil?
  end
  
  def profile_advance
    if first_preprocessing.nil?
      adv = Array.new(@@PREPROCESSING_TASKS.size, 0)
       else
      adv = []
      state = 0
      first_task = first_preprocessing
      next_task = next_preprocessing
      @@PREPROCESSING_TASKS.each do |task|
	state = 1 if first_task==task
	state = 2 if !next_task.nil? and next_task==task
	adv << state
      end
    end
    adv
  end

  private
    
    def result_files_exist?(base, files)
      files.all? do |f|
        File.exist?(base + f) or File.exist?(base + f + ".gz")
      end
    end

end # class MiGA::Dataset

