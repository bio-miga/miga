# @package MiGA
# @license Artistic-2.0

require "miga/metadata"
require "miga/dataset/result"
require "sqlite3"

##
# Dataset representation in MiGA.
class MiGA::Dataset < MiGA::MiGA
  
  include MiGA::Dataset::Result
  
  # Class-level
  class << self

    ##
    # Does the +project+ already have a dataset with that +name+?
    def exist?(project, name)
      project.dataset_names.include? name
    end

    ##
    # Standard fields of metadata for datasets.
    def INFO_FIELDS
      %w(name created updated type ref user description comments)
    end
  
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
      (k=="name") ? self.name : metadata[k.to_sym]
    end
  end
  
  ##
  # Is this dataset a reference?
  def is_ref? ; !!metadata[:ref] ; end

  ##
  # Is this dataset a query (non-reference)?
  def is_query? ; !metadata[:ref] ; end
  
  ##
  # Is this dataset known to be multi-organism?
  def is_multi?
    return false if metadata[:type].nil? or
      @@KNOWN_TYPES[type].nil?
    @@KNOWN_TYPES[type][:multi]
  end
  
  ##
  # Is this dataset known to be single-organism?
  def is_nonmulti?
    return false if metadata[:type].nil? or
      @@KNOWN_TYPES[type].nil?
    !@@KNOWN_TYPES[type][:multi]
  end
  
  ##
  # Should I ignore +task+ for this dataset?
  def ignore_task?(task)
    return !metadata["run_#{task}"] unless metadata["run_#{task}"].nil?
    return true if task==:taxonomy and project.metadata[:ref_project].nil?
    pattern = [true, false]
    ( [@@_EXCLUDE_NOREF_TASKS_H[task], is_ref?     ]==pattern or
      [@@_ONLY_MULTI_TASKS_H[task],    is_multi?   ]==pattern or
      [@@_ONLY_NONMULTI_TASKS_H[task], is_nonmulti?]==pattern )
  end

  ##
  # Returns an Array of +how_many+ duples (Arrays) sorted by AAI:
  # - +0+: A String with the name(s) of the reference dataset.
  # - +1+: A Float with the AAI.
  # This function is currently only supported for query datasets when
  # +ref_project+ is false (default), and only for reference dataset when
  # +ref_project+ is true. It returns +nil+ if this analysis is not supported.
  def closest_relatives(how_many=1, ref_project=false)
    return nil if (is_ref? != ref_project) or is_multi?
    r = result(ref_project ? :taxonomy : :distances)
    return nil if r.nil?
    db = SQLite3::Database.new(r.file_path :aai_db)
    db.execute("SELECT seq2, aai FROM aai WHERE seq2 != ? " +
      "GROUP BY seq2 ORDER BY aai DESC LIMIT ?", [name, how_many])
  end

end # class MiGA::Dataset

