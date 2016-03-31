# @package MiGA
# @license artistic license 2.0

require "miga/metadata"
require "miga/result"

class MiGA::Dataset < MiGA::MiGA
  
  # Class-level

  ##
  # Directories containing the results from dataset-specific tasks.
  def self.RESULT_DIRS ; @@RESULT_DIRS end
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

  ##
  # Supported dataset types.
  def self.KNOWN_TYPES ; @@KNOWN_TYPES end
  @@KNOWN_TYPES = {
    genome: {description: "The genome from an isolate.", multi: false},
    metagenome: {description: "A metagenome (excluding viromes).",
      multi: true},
    virome: {description: "A viral metagenome.", multi: true},
    scgenome: {description: "A genome from a single cell.", multi: false},
    popgenome: {description: "The genome of a population (including " +
      "microdiversity).", :multi=>false}
  }

  ##
  # Returns an Array of tasks to be executed before project-wide tasks.
  def self.PREPROCESSING_TASKS ; @@PREPROCESSING_TASKS ; end
  @@PREPROCESSING_TASKS = [:raw_reads, :trimmed_reads, :read_quality,
    :trimmed_fasta, :assembly, :cds, :essential_genes, :ssu, :mytaxa,
    :mytaxa_scan, :distances]
  
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
  # MiGA::Project that contains the dataset.
  attr_reader :project
  
  ##
  # Datasets are uniquely identified by +name+ in a project.
  attr_reader :name
  
  ##
  # MiGA::Metadata with information about the dataset.
  attr_reader :metadata
  
  ##
  # Create a MiGA::Dataset object in a +project+ MiGA::Project with a
  # uniquely identifying +name+. +is_ref+ indicates if the dataset is to
  # be treated as reference (true, default) or query (false). Pass any
  # additional +metadata+ as a Hash.
  def initialize(project, name, is_ref=true, metadata={})
    raise "Invalid name '#{name}', please use only alphanumerics and " +
      "underscores." unless name.miga_name?
    @project = project
    @name = name
    metadata[:ref] = is_ref
    @metadata = MiGA::Metadata.new(project.path + "/metadata/" + name + ".json",
      metadata)
  end
  
  ##
  # Save any changes you've made in the dataset.
  def save
    self.metadata[:type] = :metagenome if !metadata[:tax].nil? and
      !metadata[:tax][:ns].nil? and metadata[:tax][:ns]=="COMMUNITY"
    self.metadata.save
  end
  
  ##
  # Delete the dataset with all it's contents (including results) and returns
  # nil.
  def remove!
    self.results.each{ |r| r.remove! }
    self.metadata.remove!
  end
  
  ##
  # Get standard metadata values for the dataset as Array.
  def info
    MiGA::Dataset.INFO_FIELDS.map do |k|
      (k=="name") ? self.name : self.metadata[k.to_sym]
    end
  end
  
  ##
  # Is this dataset a reference?
  def is_ref? ; !!self.metadata[:ref] ; end
  
  ##
  # Is this dataset known to be multi-organism?
  def is_multi?
    return false if self.metadata[:type].nil?
    return @@KNOWN_TYPES[self.metadata[:type]][:multi]
  end
  
  ##
  # Is this dataset known to be single-organism?
  def is_nonmulti?
    return false if self.metadata[:type].nil?
    return !@@KNOWN_TYPES[self.metadata[:type]][:multi]
  end
  
  ##
  # Get the result MiGA::Result in this dataset identified by the symbol +k+.
  def result(k)
    return nil if @@RESULT_DIRS[k.to_sym].nil?
    MiGA::Result.load(project.path + "/data/" + @@RESULT_DIRS[k.to_sym] +
      "/" + name + ".json")
  end
  
  ##
  # Get all the results (Array of MiGA::Result) in this dataset.
  def results ; @@RESULT_DIRS.keys.map{ |k| result k }.compact ; end
  
  ##
  # For each result executes the 2-ary +blk+ block: key symbol and MiGA::Result.
  def each_result(&blk)
    @@RESULT_DIRS.keys.each do |k|
      blk.call(k, result(k)) unless result(k).nil?
    end
  end
  
  ##
  # Look for the result with symbol key +result_type+ and register it in the
  # dataset. Returns the result MiGA::Result or nil.
  def add_result(result_type)
    return nil if @@RESULT_DIRS[result_type].nil?
    base = project.path + "/data/" + @@RESULT_DIRS[result_type] +
      "/" + name
    return nil unless result_files_exist?(base, ".done")
    r = self.send("add_result_#{result_type}", base)
    r.save unless r.nil?
    r
  end

  ##
  # Returns the key symbol of the first registered result (sorted by the
  # execution order). This typically corresponds to the result used as the
  # initial input.
  def first_preprocessing
    @@PREPROCESSING_TASKS.find{ |t| not self.add_result(t).nil? }
  end
  
  ##
  # Returns the key symbol of the next task that needs to be executed.
  def next_preprocessing
    after_first = false
    first = first_preprocessing
    return nil if first.nil?
    @@PREPROCESSING_TASKS.each do |t|
      next if ignore_task? t
      return t if after_first and add_result(t).nil?
      after_first = (after_first or (t==first))
    end
    nil
  end

  ##
  # Should I ignore +task+ for this dataset?
  def ignore_task?(task)
    ( (@@EXCLUDE_NOREF_TASKS.include?(task) and not is_ref?) or
      (@@ONLY_MULTI_TASKS.include?(task) and not is_multi?) or
      (@@ONLY_NONMULTI_TASKS.include?(task) and not is_nonmulti?))
  end
  
  ##
  # Are all the dataset-specific tasks done?
  def done_preprocessing?
    !first_preprocessing.nil? and next_preprocessing.nil?
  end
  
  ##
  # Returns an array indicating the stage of each task (sorted by execution
  # order). The values are integers:
  # - 0 for an undefined result (a task before the initial input).
  # - 1 for a registered result (a completed task).
  # - 2 for a queued result (a task yet to be executed).
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
    
    def add_result_raw_reads(base)
      return nil unless result_files_exist?(base, ".1.fastq")
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name,
        ( result_files_exist?(base, ".2.fastq") ?
          {:pair1=>".1.fastq", :pair2=>".2.fastq"} :
          {:single=>".1.fastq"} ))
    end

    def add_result_trimmed_reads(base)
      return nil unless result_files_exist?(base, ".1.clipped.fastq")
      r = MiGA::Result.new base + ".json"
      r = add_files_to_ds_result(r, name,
        {:pair1=>".1.clipped.fastq", :pair2=>".2.clipped.fastq"}) if
        result_files_exist?(base, ".2.clipped.fastq")
      r.add_file(:single, name + ".1.clipped.single.fastq")
      add_result(:raw_reads) #-> Post gunzip
      r
    end

    def add_result_read_quality(base)
      return nil unless result_files_exist?(base, %w[.solexaqa .fastqc])
      r = MiGA::Result.new(base + ".json")
      r = add_files_to_ds_result(r, name,
        {:solexaqa=>".solexaqa", :fastqc=>".fastqc"})
      add_result(:trimmed_reads) #-> Post cleaning
      r
    end

    def add_result_trimmed_fasta(base)
      return nil unless
        result_files_exist?(base, ".CoupledReads.fa") or
        result_files_exist?(base, ".SingleReads.fa")
      r = MiGA::Result.new base + ".json"
      r = add_files_to_ds_result(r, name, {:coupled=>".CoupledReads.fa",
        :pair1=>".1.fa", :pair2=>".2.fa"}) if
        result_files_exist?(base, ".CoupledReads.fa")
      r.add_file(:single, name + ".SingleReads.fa")
      add_result(:raw_reads) #-> Post gzip
      r
    end

    def add_result_assembly(base)
      return nil unless result_files_exist?(base, ".LargeContigs.fna")
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {:largecontigs=>".LargeContigs.fna",
        :allcontigs=>".AllContigs.fna"})
    end

    def add_result_cds(base)
      return nil unless result_files_exist?(base, %w[.faa .fna])
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {:proteins=>".faa", :genes=>".fna",
        :gff2=>".gff2", :gff3=>".gff3", :tab=>".tab"})
    end

    def add_result_essential_genes(base)
      return nil unless result_files_exist?(base, %w[.ess.faa .ess .ess/log])
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {:ess_genes=>".ess.faa",
        :collection=>".ess", :report=>".ess/log"})
    end

    def add_result_ssu(base)
      return MiGA::Result.new(base + ".json") if result(:assembly).nil?
      return nil unless result_files_exist?(base, ".ssu.fa")
      r = MiGA::Result.new(base + ".json")
      add_files_to_ds_result(r, name, {:longest_ssu_gene=>".ssu.fa",
        :gff=>".ssu.gff", :all_ssu_genes=>".ssu.all.fa"})
    end

    def add_result_mytaxa(base)
      if is_multi?
        return nil unless result_files_exist?(base, ".mytaxa")
        r = MiGA::Result.new(base + ".json")
        add_files_to_ds_result(r, name, {:mytaxa=>".mytaxa", :blast=>".blast",
          :mytaxain=>".mytaxain"})
      else
        MiGA::Result.new base + ".json"
      end
    end

    def add_result_mytaxa_scan(base)
      if is_nonmulti?
        return nil unless
          result_files_exist?(base, %w[.pdf .wintax .mytaxa .reg])
        r = MiGA::Result.new(base + ".json")
        add_files_to_ds_result(r, name, {:mytaxa=>".mytaxa", :wintax=>".wintax",
          :blast=>".blast", :mytaxain=>".mytaxain", :report=>".pdf",
          :regions=>".reg", :gene_ids=>".wintax.genes",
          :region_ids=>".wintax.regions"})
      else
        MiGA::Result.new base + ".json"
      end
    end

    def add_result_distances(base)
      if is_nonmulti?
        pref = project.path + "/data/" + @@RESULT_DIRS[result_type]
        return nil unless
          File.exist?("#{pref}/#{is_ref? ? "01.haai" : "02.aai"}/#{name}.db")
        r = MiGA::Result.new(base + ".json")
        r.add_files({:haai_db=>"01.haai/#{name}.db",
          :aai_db=>"02.aai/#{name}.db", :ani_db=>"03.ani/#{name}.db"})
      else
        r = MiGA::Result.new "#{base}.json"
      end
      r
    end

    def add_files_to_ds_result(r, name, rel_files)
      files = {}
      rel_files.each{ |k,v| files[k] = name + v }
      r.add_files(files)
      r
    end

end # class MiGA::Dataset
