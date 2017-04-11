# @package MiGA
# @license Artistic-2.0

require "miga/metadata"
require "miga/result"
require "miga/dataset_result"

##
# Dataset representation in MiGA.
class MiGA::Dataset < MiGA::MiGA
  
  include MiGA::DatasetResult
  
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
    # Distances (for single-species datasets)
    distances: "09.distances",
    # General statistics
    stats: "90.stats"
  }

  ##
  # Supported dataset types.
  def self.KNOWN_TYPES ; @@KNOWN_TYPES end
  @@KNOWN_TYPES = {
    genome: {description: "The genome from an isolate.", multi: false},
    metagenome: {description: "A metagenome (excluding viromes).",
      multi: true},
    virome: {description: "A viral metagenome.", multi: true},
    scgenome: {description: "A Single-cell Genome Amplification (SGA).",
      multi: false},
    popgenome: {description: "A population genome (including " +
      "metagenomic bins).", :multi=>false}
  }

  ##
  # Returns an Array of tasks to be executed before project-wide tasks.
  def self.PREPROCESSING_TASKS ; @@PREPROCESSING_TASKS ; end
  @@PREPROCESSING_TASKS = [:raw_reads, :trimmed_reads, :read_quality,
    :trimmed_fasta, :assembly, :cds, :essential_genes, :ssu, :mytaxa,
    :mytaxa_scan, :distances, :stats]
  
  ##
  # Tasks to be excluded from query datasets.
  @@EXCLUDE_NOREF_TASKS = [:mytaxa_scan]
  @@_EXCLUDE_NOREF_TASKS_H = Hash[@@EXCLUDE_NOREF_TASKS.map{ |i| [i,true] }]
  
  ##
  # Tasks to be executed only in datasets that are not multi-organism. These
  # tasks are ignored for multi-organism datasets or for unknown types.
  @@ONLY_NONMULTI_TASKS = [:mytaxa_scan, :distances]
  @@_ONLY_NONMULTI_TASKS_H = Hash[@@ONLY_NONMULTI_TASKS.map{ |i| [i,true] }]

  ##
  # Tasks to be executed only in datasets that are multi-organism. These
  # tasks are ignored for single-organism datasets or for unknwon types.
  @@ONLY_MULTI_TASKS = [:mytaxa]
  @@_ONLY_MULTI_TASKS_H = Hash[@@ONLY_MULTI_TASKS.map{ |i| [i,true] }]

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
    @metadata = MiGA::Metadata.new(
      File.expand_path("metadata/#{name}.json", project.path), metadata )
  end
  
  ##
  # Save any changes you've made in the dataset.
  def save
    self.metadata[:type] = :metagenome if !metadata[:tax].nil? and
      !metadata[:tax][:ns].nil? and metadata[:tax][:ns]=="COMMUNITY"
    self.metadata.save
  end
  
  ##
  # Get the type of dataset as Symbol.
  def type ; metadata[:type] ; end
  
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
    return false if self.metadata[:type].nil? or
      @@KNOWN_TYPES[self.metadata[:type]].nil?
    @@KNOWN_TYPES[self.metadata[:type]][:multi]
  end
  
  ##
  # Is this dataset known to be single-organism?
  def is_nonmulti?
    return false if self.metadata[:type].nil? or
      @@KNOWN_TYPES[self.metadata[:type]].nil?
    !@@KNOWN_TYPES[self.metadata[:type]][:multi]
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
  # dataset. If +save+ is false, it doesn't register the result, but it still
  # returns a result if the expected files are complete. The +opts+ array
  # controls result creation (if necessary). Supported values include:
  # * +is_clean+: A Boolean indicating if the input files are clean.
  # Returns MiGA::Result or nil.
  def add_result(result_type, save=true, opts={})
    return nil if @@RESULT_DIRS[result_type].nil?
    base = File.expand_path("data/#{@@RESULT_DIRS[result_type]}/#{name}",
              project.path)
    r_pre = MiGA::Result.load("#{base}.json")
    return r_pre if (r_pre.nil? and not save) or not r_pre.nil?
    return nil unless result_files_exist?(base, ".done")
    r = self.send("add_result_#{result_type}", base, opts)
    r.save unless r.nil?
    r
  end

  ##
  # Gets a result as MiGA::Result for the datasets with +result_type+. This is
  # equivalent to +add_result(result_type, false)+.
  def get_result(result_type) ; add_result(result_type, false) ; end

  ##
  # Returns the key symbol of the first registered result (sorted by the
  # execution order). This typically corresponds to the result used as the
  # initial input. Passes +save+ to #add_result.
  def first_preprocessing(save=false)
    @@PREPROCESSING_TASKS.find do |t|
      not ignore_task?(t) and not add_result(t, save).nil?
    end
  end
  
  ##
  # Returns the key symbol of the next task that needs to be executed. Passes
  # +save+ to #add_result.
  def next_preprocessing(save=false)
    after_first = false
    first = first_preprocessing(save)
    return nil if first.nil?
    @@PREPROCESSING_TASKS.each do |t|
      next if ignore_task? t
      return t if after_first and add_result(t, save).nil?
      after_first = (after_first or (t==first))
    end
    nil
  end

  ##
  # Should I ignore +task+ for this dataset?
  def ignore_task?(task)
    return !metadata["run_#{task}"] unless metadata["run_#{task}"].nil?
    ( (@@_EXCLUDE_NOREF_TASKS_H[task] and not is_ref?) or
      (@@_ONLY_MULTI_TASKS_H[task] and not is_multi?) or
      (@@_ONLY_NONMULTI_TASKS_H[task] and not is_nonmulti?))
  end
  
  ##
  # Are all the dataset-specific tasks done? Passes +save+ to #add_result.
  def done_preprocessing?(save=false)
    !first_preprocessing(save).nil? and next_preprocessing(save).nil?
  end
  
  ##
  # Returns an array indicating the stage of each task (sorted by execution
  # order). The values are integers:
  # - 0 for an undefined result (a task before the initial input).
  # - 1 for a registered result (a completed task).
  # - 2 for a queued result (a task yet to be executed).
  # It passes +save+ to #add_result
  def profile_advance(save=false)
    first_task = first_preprocessing(save)
    return Array.new(@@PREPROCESSING_TASKS.size, 0) if first_task.nil?
    adv = []
    state = 0
    next_task = next_preprocessing(save)
    @@PREPROCESSING_TASKS.each do |task|
      state = 1 if first_task==task
      state = 2 if !next_task.nil? and next_task==task
      adv << state
    end
    adv
  end

end # class MiGA::Dataset
