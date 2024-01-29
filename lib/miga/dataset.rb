# frozen_string_literal: true

# @package MiGA
# @license Artistic-2.0

require 'miga/metadata'
require 'miga/dataset/result'
require 'miga/dataset/status'
require 'miga/dataset/type'
require 'miga/dataset/hooks'

# This library is only required by +#closest_relatives+, so it is now
# being loaded on call instead to allow most of miga-base to work without
# issue in systems with problematic SQLite3 installations.
# require 'miga/sqlite'

##
# Dataset representation in MiGA
class MiGA::Dataset < MiGA::MiGA
  include MiGA::Dataset::Result
  include MiGA::Dataset::Status
  include MiGA::Dataset::Type
  include MiGA::Dataset::Hooks

  # Class-level
  class << self
    ##
    # Does the +project+ already have a dataset with that +name+?
    def exist?(project, name)
      !project.dataset_names_hash[name].nil?
    end

    ##
    # Standard fields of metadata for datasets
    def INFO_FIELDS
      %w[name created updated type ref user description comments]
    end
  end

  # Instance-level

  ##
  # MiGA::Project that contains the dataset
  attr_reader :project

  ##
  # Datasets are uniquely identified by +name+ in a project
  attr_reader :name

  ##
  # Create a MiGA::Dataset object in a +project+ MiGA::Project with a
  # uniquely identifying +name+. +is_ref+ indicates if the dataset is to
  # be treated as reference (true, default) or query (false). Pass any
  # additional +metadata+ as a Hash.
  def initialize(project, name, is_ref = true, metadata = {})
    name = name.to_s
    name.miga_name? or
      raise 'Invalid name, please use only alphanumerics and underscores: ' +
            name

    @project, @name, @metadata = project, name, nil
    metadata[:ref] = is_ref
    metadata[:type] ||= :empty
    @metadata_future = [
      File.join(project.path, 'metadata', "#{name}.json"),
      metadata
    ]
    return if File.exist? @metadata_future[0]

    save
    pull_hook :on_create
  end

  ##
  # MiGA::Metadata with information about the dataset
  def metadata
    if @metadata.nil?
      @metadata = MiGA::Metadata.new(*@metadata_future)
      pull_hook :on_load
    end
    @metadata
  end

  ##
  # Save any changes you've made in the dataset
  def save
    MiGA.DEBUG "Dataset.metadata: #{metadata.data}"
    metadata.save
    pull_hook :on_save
  end

  ##
  # Currently +save!+ is simply an alias of +save+, for compatibility with the
  # +Project+ interface
  alias :save! :save

  ##
  # Delete the dataset with all it's contents (including results) and returns
  # nil
  def remove!
    results.each(&:remove!)
    metadata.remove!
    pull_hook :on_remove
  end

  ##
  # Inactivate a dataset. This halts automated processing by the daemon
  # 
  # If given, the +reason+ string is saved as a metadata +:warn+ entry
  def inactivate!(reason = nil)
    metadata[:warn] = "Inactive: #{reason}" unless reason.nil?
    metadata[:inactive] = true
    metadata.save
    project.recalculate_tasks("Reference dataset inactivated: #{name}") if ref?
    pull_hook :on_inactivate
  end

  ##
  # Activate a dataset. This removes the +:inactive+ flag
  def activate!
    metadata[:inactive] = nil
    metadata[:warn] = nil if metadata[:warn] && metadata[:warn] =~ /^Inactive: /
    metadata.save
    project.recalculate_tasks("Reference dataset activated: #{name}") if ref?
    pull_hook :on_activate
  end

  ##
  # Get standard metadata values for the dataset as Array
  def info
    MiGA::Dataset.INFO_FIELDS.map do |k|
      k == 'name' ? name : metadata[k]
    end
  end

  ##
  # Is this dataset a reference?
  def ref?
    !query?
  end

  ##
  # Is this dataset a query (non-reference)?
  def query?
    !metadata[:ref]
  end

  ##
  # Is this dataset active?
  def active?
    metadata[:inactive].nil? or !metadata[:inactive]
  end

  ##
  # Same as +ref?+ for backwards-compatibility
  alias is_ref? ref?

  ##
  # Same as +query?+ for backwards-compatibility
  alias is_query? query?

  ##
  # Same as +multi?+ for backwards-compatibility
  alias is_multi? multi?

  ##
  # Same as +is_nonmulti?+ for backwards-compatibility
  alias is_nonmulti? nonmulti?

  ##
  # Same as +active?+ for backwards-compatibility
  alias is_active? active?

  ##
  # Returns an Array of +how_many+ duples (Arrays) sorted by AAI:
  # - +0+: A String with the name(s) of the reference dataset.
  # - +1+: A Float with the AAI.
  # This function is currently only supported for query datasets when
  # +ref_project+ is false (default), and only for reference dataset when
  # +ref_project+ is true. It returns +nil+ if this analysis is not supported.
  def closest_relatives(how_many = 1, ref_project = false)
    return nil if (ref? != ref_project) || multi?

    r = result(ref_project ? :taxonomy : :distances)
    return nil if r.nil?

    require 'miga/sqlite'
    MiGA::SQLite.new(r.file_path(:aai_db)).run(
      'SELECT seq2, aai FROM aai WHERE seq2 != ? ' \
      'GROUP BY seq2 ORDER BY aai DESC LIMIT ?', [name, how_many]
    )
  end
end
