# @package MiGA
# @license Artistic-2.0

require 'miga/dataset'
require 'miga/project/result'
require 'miga/project/dataset'
require 'miga/project/hooks'

##
# MiGA representation of a project
class MiGA::Project < MiGA::MiGA
  include MiGA::Project::Result
  include MiGA::Project::Dataset
  include MiGA::Project::Hooks

  ##
  # Absolute path to the project folder
  attr_reader :path

  ##
  # Information about the project as MiGA::Metadata
  attr_reader :metadata

  ##
  # If true, it doesn't save changes
  attr_accessor :do_not_save

  ##
  # Create a new MiGA::Project at +path+, if it doesn't exist and +update+ is
  # false, or load an existing one.
  def initialize(path, update = false)
    @datasets = {}
    @do_not_save = false
    @path = File.absolute_path(path)
    self.create if !update && !Project.exist?(self.path)
    self.load if self.metadata.nil?
    self.metadata[:type] = :mixed if type.nil?
    raise "Unrecognized project type: #{type}" if @@KNOWN_TYPES[type].nil?
  end

  ##
  # Create an empty project
  def create
    unless MiGA::MiGA.initialized?
      warn 'Projects cannot be processed yet, first run: miga init'
    end

    dirs = @@FOLDERS.map { |d| File.join(path, d) }
    dirs += @@DATA_FOLDERS.map { |d| File.join(path, 'data', d) }
    dirs.each { |d| FileUtils.mkdir_p(d) }
    @metadata = MiGA::Metadata.new(
      File.join(path, 'miga.project.json'),
      datasets: [], name: File.basename(path)
    )
    d_path = File.join(path, 'daemon', 'daemon.json')
    File.open(d_path, 'w') { |fh| fh.puts '{}' } unless File.exist?(d_path)
    pull_hook :on_create
    self.load
  end

  ##
  # Save any changes persistently. Do nothing if +do_not_save+ is true
  def save
    save! unless do_not_save
  end

  ##
  # Save any changes persistently, regardless of +do_not_save+
  def save!
    metadata.save!
    pull_hook :on_save
    self.load
  end

  ##
  # (Re-)load project data and metadata
  def load
    @datasets = {}
    @dataset_names_hash = nil
    @metadata = MiGA::Metadata.load "#{path}/miga.project.json"
    raise "Couldn't find project metadata at #{path}" if metadata.nil?

    pull_hook :on_load
  end

  ##
  # Name of the project
  def name
    metadata[:name]
  end

  ##
  # Type of project
  def type
    metadata[:type]
  end

  ##
  # Is this a clade project?
  def clade?
    %i[clade plasmids].include? type
  end

  ##
  # Same as active? For backward compatibility
  alias is_clade? clade?

  ##
  # Is this a project for multi-organism datasets?
  def multi?
    @@KNOWN_TYPES[type][:multi]
  end

  ##
  # Same as multi? For backward compatibility
  alias is_multi? multi?

  ##
  # Does the project support the use of universal markers?
  def markers?
    @@KNOWN_TYPES[type][:markers]
  end

  ##
  # Is this project active? Currently a dummy function, returns
  # always true.
  def active?
    true
  end

  ##
  # Load or recover the project's daemon
  def daemon
    require 'miga/daemon'
    @daemon ||= MiGA::Daemon.new(self)
  end

  ##
  # Retrieves the option with name +key+ from the project's metadata,
  # extending support to relative paths in +:ref_project+ and
  # +:db_proj_dir+
  def option_by_metadata(key)
    case key.to_sym
    when :ref_project, :db_proj_dir
      y = metadata[key]
      y = File.expand_path(y, path) if y && y =~ /^[^\/]/
      return y
    end

    super
  end
end
