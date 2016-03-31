# @package MiGA
# @license artistic license 2.0

require "miga/dataset"

class MiGA::Project < MiGA::MiGA
  
  # Class

  ##
  # Top-level folders inside a project.
  @@FOLDERS = %w[data metadata daemon]

  ##
  # Folders for results.
  @@DATA_FOLDERS = %w[
    01.raw_reads 02.trimmed_reads 03.read_quality 04.trimmed_fasta
    05.assembly 06.cds
    07.annotation 07.annotation/01.function 07.annotation/02.taxonomy
    07.annotation/01.function/01.essential
    07.annotation/01.function/02.ssu
    07.annotation/02.taxonomy/01.mytaxa
    07.annotation/03.qa 07.annotation/03.qa/01.checkm
    07.annotation/03.qa/02.mytaxa_scan
    08.mapping 08.mapping/01.read-ctg 08.mapping/02.read-gene
    09.distances 09.distances/01.haai 09.distances/02.aai
    09.distances/03.ani 09.distances/04.ssu
    10.clades 10.clades/01.find 10.clades/02.ani 10.clades/03.ogs
    10.clades/04.phylogeny 10.clades/04.phylogeny/01.essential
    10.clades/04.phylogeny/02.core 10.clades/05.metadata
  ]

  ##
  # Directories containing the results from project-wide tasks.
  def self.RESULT_DIRS ; @@RESULT_DIRS ; end
  @@RESULT_DIRS = {
    # Distances
    haai_distances: "09.distances/01.haai",
    aai_distances: "09.distances/02.aai",
    ani_distances: "09.distances/03.ani",
    #ssu_distances: "09.distances/04.ssu",
    # Clade identification
    clade_finding: "10.clades/01.find",
    # Clade analysis
    subclades: "10.clades/02.ani",
    ogs: "10.clades/03.ogs",
    ess_phylogeny: "10.clades/04.phylogeny/01.essential",
    core_phylogeny: "10.clades/04.phylogeny/02.core",
    clade_metadata: "10.clades/05.metadata"
  }

  ##
  # Supported types of projects.
  def self.KNOWN_TYPES ; @@KNOWN_TYPES ; end
  @@KNOWN_TYPES = {
    mixed: {
      description: "Mixed collection of genomes, metagenomes, and viromes.",
      single: true, multi: true},
    genomes: {description: "Collection of genomes.",
      single: true, multi: false},
    clade: {description: "Collection of closely-related genomes (ANI <= 90%).",
      single: true, multi: false},
    metagenomes: {description: "Collection of metagenomes and/or viromes.",
      single: false, multi: true}
  }

  ##
  # Project-wide distance estimations.
  def self.DISTANCE_TASKS ; @@DISTANCE_TASKS ; end
  @@DISTANCE_TASKS = [:haai_distances, :aai_distances, :ani_distances,
    :clade_finding]
  
  ##
  # Project-wide tasks for :clade projects.
  def self.INCLADE_TASKS ; @@INCLADE_TASKS ; end
  @@INCLADE_TASKS = [:subclades, :ogs, :ess_phylogeny, :core_phylogeny,
    :clade_metadata]
  
  ##
  # Does the project at +path+ exist?
  def self.exist?(path)
    Dir.exist?(path) and File.exist?(path + "/miga.project.json")
  end

  ##
  # Load the project at +path+. Returns MiGA::Project if project exists, nil
  # otherwise.
  def self.load(path)
    return nil unless Project.exist? path
    Project.new path
  end

  # Instance
  
  # Absolute path to the project folder.
  attr_reader :path
  # Information about the project as MiGA::Metadata.
  attr_reader :metadata

  def initialize(path, update=false)
    @datasets = {}
    @path = File.absolute_path(path)
    self.create if update or not Project.exist? self.path
    self.load if self.metadata.nil?
  end

  def create
    unless MiGA::MiGA.initialized?
      raise "Impossible to create project in uninitialized MiGA."
    end
    Dir.mkdir self.path unless Dir.exist? self.path
    @@FOLDERS.each do |dir|
      Dir.mkdir self.path + "/" + dir unless
	Dir.exist? self.path + "/" + dir
    end
    @@DATA_FOLDERS.each do |dir|
      Dir.mkdir self.path + "/data/" + dir unless
	Dir.exist? self.path + "/data/" + dir
    end
    @metadata = Metadata.new(self.path + "/miga.project.json",
      {datasets: [], name: File.basename(self.path)})
    FileUtils.cp(ENV["MIGA_HOME"] + "/.miga_daemon.json",
      self.path + "/daemon/daemon.json") unless
      File.exist? self.path + "/daemon/daemon.json"
    self.load
  end
  
  def save
    self.metadata.save
    self.load
  end
  
  def load
    @metadata = Metadata.load self.path + "/miga.project.json"
    raise "Couldn't find project metadata at #{self.path}" if
      self.metadata.nil?
  end
  
  def name ; self.metadata[:name] ; end
  
  def datasets
    self.metadata[:datasets].map{ |name| self.dataset name }
  end
  
  def dataset(name)
    name = name.miga_name
    @datasets = {} if @datasets.nil?
    @datasets[name] = Dataset.new(self, name) if @datasets[name].nil? 
    @datasets[name]
  end
  
  def each_dataset(&blk)
    self.metadata[:datasets].each{ |name| blk.call(self.dataset name) }
  end
  
  def add_dataset(name)
    self.metadata[:datasets] << name unless
      self.metadata[:datasets].include? name
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
  
  def import_dataset(ds, method=:hardlink)
    raise "Impossible to import dataset, it already exists: #{ds.name}." if
      Dataset.exist?(self, ds.name)
    # Import dataset results
    ds.each_result do |task, result|
      # import result files
      result.each_file do |file|
	File.generic_transfer("#{result.dir}/#{file}",
	  "#{self.path}/data/#{Dataset.RESULT_DIRS[task]}/#{file}",
	  method)
      end
      # import result metadata
      %w(json start done).each do |suffix|
	if File.exist? "#{result.dir}/#{ds.name}.#{suffix}"
	  File.generic_transfer("#{result.dir}/#{ds.name}.#{suffix}",
	    "#{self.path}/data/#{Dataset.RESULT_DIRS[task]}/" +
		      "#{ds.name}.#{suffix}",
	    method)
	end
      end
    end
    # Import dataset metadata
    File.generic_transfer("#{ds.project.path}/metadata/#{ds.name}.json",
      "#{self.path}/metadata/#{ds.name}.json", method)
    # Save dataset
    self.add_dataset ds.name 
  end
  
  def result(name)
    return nil if @@RESULT_DIRS[name.to_sym].nil?
    Result.load self.path + "/data/" + @@RESULT_DIRS[name.to_sym] + 
      "/miga-project.json"
  end
  
  def results
    @@RESULT_DIRS.keys.map{ |k| self.result k }.reject{ |r| r.nil? }
  end
  
  def add_result result_type
    return nil if @@RESULT_DIRS[result_type].nil?
    base = self.path + "/data/" + @@RESULT_DIRS[result_type] +
      "/miga-project"
    return nil unless result_files_exist?(base, ".done")
    r = self.call("add_result_#{result_type}", base)
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
	next unless
	  file =~ %r{
	    \.(fa(a|sta|stqc?)?|fna|solexaqa|gff[23]?|done|ess)(\.gz)?$
	    }x
	m = /([^\.]+)/.match(file)
	datasets << m[1] unless m.nil? or m[1] == "miga-project"
      end
    end
    datasets.uniq - self.metadata[:datasets]
  end
  
  def done_preprocessing?
    self.datasets.map{|ds| (not ds.is_ref?) or ds.done_preprocessing?}.all?
  end
  
  ##
  # Returns a two-dimensional matrix (Array of Array) where the first index
  # corresponds to the dataset, the second index corresponds to the dataset
  # task, and the value corresponds to:
  # - 0: Before execution.
  # - 1: Done (or not required).
  # - 2: To do.
  def profile_datasets_advance
    advance = []
    self.each_dataset_profile_advance do |ds_adv|
      advance << ds_adv
    end
    advance
  end

  def each_dataset_profile_advance(&blk)
    self.each_dataset do |ds|
      blk.call(ds.profile_advance)
    end
  end

  private

    def add_result_distances(base)
      return nil unless result_files_exist?(base, %w[.Rdata .log .txt])
      r = Result.new(base + ".json")
      r.add_file(:rdata, "miga-project.Rdata")
      r.add_file(:matrix, "miga-project.txt")
      r.add_file(:log, "miga-project.log")
      r.add_file(:hist, "miga-project.hist")
      r
    end

    def add_result_clade_finding(base)
      return nil unless result_files_exist?(base, %w[.proposed-clades])
      r = Result.new(base + ".json")
      r.add_file(:proposal, "miga-project.proposed-clades")
      r.add_file(:rbm_aai90, "genome-genome.aai90.rbm")
      r.add_file(:clades_aai90, "miga-project.ani-clades")
      r.add_file(:rbm_ani95, "genome-genome.ani95.rbm")
      r.add_file(:clades_ani95, "miga-project.ani95-clades")
      r
    end

    def add_result_subclades(base)
      return nil unless
	result_files_exist?(base,
	%w[.pdf .1.classif .1.medoids .class.tsv .class.nwk])
      r = Result.new(base + ".json")
      r.add_file(:report, "miga-project.pdf")
      (1..6).each do |i|
	%w{classif medoids}.each do |m|
	  r.add_file("#{m}_#{i}".to_sym, "miga-project.#{i}.#{m}")
	end
      end
      r.add_file(:class_table, "miga-project.class.tsv")
      r.add_file(:class_tree,  "miga-project.class.nwk")
      r.add_file(:ani_tree,    "miga-project.ani.nwk")
      r
    end

    def add_result_ogs(base)
      return nil unless result_files_exist?(base, %w[.ogs .stats])
      r = Result.new(base + ".json")
      r.add_file(:ogs, "miga-project.ogs")
      r.add_file(:stats, "miga-project.stats")
      r.add_file(:rbm, "miga-project.rbm")
      r
    end

    alias add_haai_distances add_result_distances
    alias add_aai_distances add_result_distances
    alias add_ani_distances add_result_distances
    alias add_ssu_distances add_result_distances
end

