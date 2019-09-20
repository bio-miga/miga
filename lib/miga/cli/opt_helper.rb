# @package MiGA
# @license Artistic-2.0

module MiGA::Cli::OptHelper 
  ##
  # Send MiGA's banner to OptionParser +opt+
  def banner(opt)
    usage = "Usage: miga #{action.name}"
    usage += ' {operation}' if expect_operation
    usage += ' [options]'
    usage += ' {FILES...}' if expect_files
    opt.banner = "\n#{task_description}\n\n#{usage}\n"
    opt.separator ''
  end

  ##
  # Common options at the end of most actions, passed to OptionParser +opt+
  # No action is performed if +#opt_common = false+ is passed
  # Executes only once, unless +#opt_common = true+ is passed between calls
  def opt_common(opt)
    return unless @opt_common
    if interactive
      opt.on(
        '--auto',
        'Accept all defaults as answers'
      ){ |v| cli[:auto] = v }
    end
    opt.on(
      '-v', '--verbose',
      'Print additional information to STDERR'
    ){ |v| self[:verbose] = v }
    opt.on(
      '-d', '--debug INT', Integer,
      'Print debugging information to STDERR (1: debug, 2: trace)'
    ){ |v| (v > 1) ? MiGA.DEBUG_TRACE_ON : MiGA.DEBUG_ON }
    opt.on(
      '-h', '--help',
      'Display this screen'
    ){ puts opt ; exit }
    opt.separator ''
    self.opt_common = false
  end

  ##
  # Options to load an object passed to OptionParser +opt+, as determined
  # by +what+ an Array with any combination of:
  # - :project To require a project
  # - :dataset To require a dataset
  # - :dataset_opt To allow (optionally) a dataset
  # - :dataset_type To allow (optionally) a type of dataset
  # - :dataset_type_req To require a type of dataset
  # - :project_type To allow (optionally) a type of project
  # - :project_type_req To require a type of project
  # - :result To require a type of project or dataset result
  # - :result_dataset To require a type of dataset result
  # - :result_project To require a type of project result
  # The options :result, :result_dataset, and :result_project are mutually
  # exclusive
  def opt_object(opt, what = [:project, :dataset])
    if what.include? :project
      opt.on(
        '-P', '--project PATH',
        '(Mandatory) Path to the project'
      ){ |v| self[:project] = v }
    end
    if what.include?(:dataset) || what.include?(:dataset_opt)
      opt.on(
        '-D', '--dataset STRING',
        (what.include?(:dataset) ? '(Mandatory) ' : '') + 'Name of the dataset'
      ){ |v| self[:dataset] = v }
    end
    if what.include? :dataset_opt
      opt.on(
        '-D', '--dataset STRING',
        'Name of the dataset'
      ){ |v| self[:dataset] = v }
    end
    if what.include?(:dataset_type) || what.include?(:dataset_type_req)
      opt.on(
        '-t', '--type STRING',
        (what.include?(:dataset_type_req) ? '(Mandatory) ' : '') +
        'Type of dataset. Recognized types include:',
        *MiGA::Dataset.KNOWN_TYPES.map{ |k,v| "~ #{k}: #{v[:description]}" }
      ){ |v| self[:type] = v.downcase.to_sym }
    end
    if what.include?(:project_type) || what.include?(:project_type_req)
      opt.on(
        '-t', '--type STRING',
        (what.include?(:project_type_req) ? '(Mandatory) ' : '') +
        'Type of project. Recognized types include:',
        *MiGA::Project.KNOWN_TYPES.map{ |k,v| "~ #{k}: #{v[:description]}"}
      ){ |v| self[:type] = v.downcase.to_sym }
    end
    if what.include? :result
      opt.on(
        '-r', '--result STRING',
        '(Mandatory) Name of the result',
        'Recognized names for dataset-specific results include:',
        *MiGA::Dataset.RESULT_DIRS.keys.map{|n| " ~ #{n}"},
        'Recognized names for project-wide results include:',
        *MiGA::Project.RESULT_DIRS.keys.map{|n| " ~ #{n}"}
      ){ |v| self[:result] = v.downcase.to_sym }
    elsif what.include? :result_dataset
      opt.on(
        '-r', '--result STRING',
        '(Mandatory) Name of the result, one of:',
        *MiGA::Dataset.RESULT_DIRS.keys.map{|n| " ~ #{n}"}
      ){ |v| self[:result] = v.downcase.to_sym }
    elsif what.include? :result_project
      opt.on(
        '-r', '--result STRING',
        '(Mandatory) Name of the result, one of:',
        *MiGA::Project.RESULT_DIRS.keys.map{|n| " ~ #{n}"}
      ){ |v| self[:result] = v.downcase.to_sym }
    end
  end

  ##
  # Options to filter a list of datasets passed to OptionParser +opt+,
  # as determined by +what+ an Array with any combination of:
  # - :ref To filter by reference (--ref) or query (--no-ref)
  # - :multi To filter by multiple (--multi) or single (--no-multi) species
  # - :active To filter by active (--active) or inactive (--no-active)
  # - :taxonomy To filter by taxonomy (--taxonomy)
  # The "k-th" filter (--dataset-k) is always included
  def opt_filter_datasets(opt, what = [:ref, :multi, :active, :taxonomy])
    if what.include? :ref
      opt.on(
        '--[no-]ref',
        'Use only reference (or only non-reference) datasets'
      ){ |v| self[:ref] = v }
    end
    if what.include? :multi
      opt.on(
        '--[no-]multi',
        'Use only multi-species (or only single-species) datasets'
      ){ |v| self[:multi] = v }
    end
    if what.include? :active
      opt.on(
        '--[no-]active',
        'Use only active (or inactive) datasets'
      ){ |v| self[:active] = v }
    end
    if what.include? :taxonomy
      opt.on(
        '-t', '--taxonomy RANK:TAXON',
        'Filter by taxonomy'
      ){ |v| self[:taxonomy] = MiGA::Taxonomy.new(v) }
    end
    opt.on(
      '--dataset-k INTEGER', Integer,
      'Use only the k-th dataset in the list'
    ){ |v| self[:dataset_k] = v }
  end
end

