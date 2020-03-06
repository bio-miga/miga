# @package MiGA
# @license Artistic-2.0

require 'miga/dataset'
require 'miga/project/result'
require 'miga/project/dataset'
require 'miga/project/hooks'
require 'miga/project/plugins'

##
# MiGA representation of a project.
class MiGA::Project < MiGA::MiGA
  
  include MiGA::Project::Result
  include MiGA::Project::Dataset
  include MiGA::Project::Hooks
  include MiGA::Project::Plugins

  ##
  # Absolute path to the project folder.
  attr_reader :path

  ##
  # Information about the project as MiGA::Metadata.
  attr_reader :metadata

  ##
  # If true, it doesn't save changes
  attr_accessor :do_not_save

  ##
  # Create a new MiGA::Project at +path+, if it doesn't exist and +update+ is
  # false, or load an existing one.
  def initialize(path, update=false)
    @datasets = {}
    @do_not_save = false
    @path = File.absolute_path(path)
    self.create if not update and not Project.exist? self.path
    self.load if self.metadata.nil?
    self.load_plugins
    self.metadata[:type] = :mixed if type.nil?
    raise "Unrecognized project type: #{type}." if @@KNOWN_TYPES[type].nil?
  end

  ##
  # Create an empty project.
  def create
    unless MiGA::MiGA.initialized?
      raise 'Impossible to create project in uninitialized MiGA.'
    end
    dirs = [path] + @@FOLDERS.map{|d| "#{path}/#{d}" } +
      @@DATA_FOLDERS.map{ |d| "#{path}/data/#{d}"}
    dirs.each{ |d| Dir.mkdir(d) unless Dir.exist? d }
    @metadata = MiGA::Metadata.new(
      File.expand_path('miga.project.json', path),
      {datasets: [], name: File.basename(path)})
    d_path = File.expand_path('daemon/daemon.json', path)
    File.open(d_path, 'w') { |fh| fh.puts '{}' } unless File.exist? d_path
    pull_hook :on_create
    self.load
  end

  ##
  # Save any changes persistently. Do nothing if +do_not_save+ is true.
  def save
    save! unless do_not_save
  end

  ##
  # Save any changes persistently, regardless of +do_not_save+.
  def save!
    metadata.save
    pull_hook :on_save
    self.load
  end

  ##
  # (Re-)load project data and metadata.
  def load
    @datasets = {}
    @dataset_names_hash = nil
    @metadata = MiGA::Metadata.load "#{path}/miga.project.json"
    raise "Couldn't find project metadata at #{path}" if metadata.nil?
    pull_hook :on_load
  end

  ##
  # Name of the project.
  def name ; metadata[:name] ; end

  ##
  # Type of project.
  def type ; metadata[:type] ; end

  ##
  # Is this a clade project?
  def is_clade? ; type==:clade ; end

  ##
  # Is this a project for multi-organism datasets?
  def is_multi? ; @@KNOWN_TYPES[type][:multi] ; end

end
