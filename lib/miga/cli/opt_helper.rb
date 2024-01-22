# frozen_string_literal: true

##
# Helper module including functions for CLI options
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
      ) { |v| self[:auto] = v }
    end
    opt.on(
      '--rand-seed INT', Integer,
      'Set this seed to initialize pseudo-randomness'
    ) { |v| srand(v) }
    opt.on(
      '-v', '--verbose',
      'Print additional information to STDERR'
    ) { |v| self[:verbose] = v }
    opt.on(
      '-d', '--debug INT', Integer,
      'Print debugging information to STDERR (1: debug, 2: trace)'
    ) { |v| v > 1 ? MiGA::MiGA.DEBUG_TRACE_ON : MiGA::MiGA.DEBUG_ON }
    opt.on(
      '-h', '--help',
      'Display this screen'
    ) do
      puts opt.to_a.select { |i| i !~ /\s::HIDE::\s/ }
      exit
    end
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
  # - :result_opt To allow (optionally) a type of result
  # - :result_dataset To require a type of dataset result
  # - :result_project To require a type of project result
  # The options :result, :result_opt, :result_dataset, and :result_project
  # are mutually exclusive
  def opt_object(opt, what = %i[project dataset])
    what.each do |w|
      case w
      when :project
        opt.on(
          '-P', '--project PATH',
          '(Mandatory) Path to the project'
        ) { |v| self[:project] = v }
      when :dataset, :dataset_opt
        opt.on(
          '-D', '--dataset STRING',
          (w == :dataset ? '(Mandatory) ' : '') + 'Name of the dataset'
        ) { |v| self[:dataset] = v }
      when :dataset_type, :dataset_type_req, :project_type, :project_type_req
        obj = w.to_s.gsub(/_.*/, '')
        klass = Object.const_get("MiGA::#{obj.capitalize}")
        req = w.to_s =~ /_req$/ ? '(Mandatory) ' : ''
        opt.on(
          '-t', '--type STRING',
          "#{req}Type of #{obj}. Recognized types include:",
          *klass.KNOWN_TYPES.map { |k, v| "~ #{k}: #{v[:description]}" }
        ) { |v| self[:type] = v.downcase.to_sym }
      when :result, :result_opt
        opt.on(
          '-r', '--result STRING',
          "#{'(Mandatory) ' if w == :result}Name of the result",
          'Recognized names for dataset-specific results include:',
          *MiGA::Dataset.RESULT_DIRS.keys.map { |n| " ~ #{n}" },
          'Recognized names for project-wide results include:',
          *MiGA::Project.RESULT_DIRS.keys.map { |n| " ~ #{n}" }
        ) { |v| self[:result] = v.downcase.to_sym }
      when :result_dataset
        opt.on(
          '-r', '--result STRING',
          '(Mandatory) Name of the result, one of:',
          *MiGA::Dataset.RESULT_DIRS.keys.map { |n| " ~ #{n}" }
        ) { |v| self[:result] = v.downcase.to_sym }
      when :result_project
        opt.on(
          '-r', '--result STRING',
          '(Mandatory) Name of the result, one of:',
          *MiGA::Project.RESULT_DIRS.keys.map { |n| " ~ #{n}" }
        ) { |v| self[:result] = v.downcase.to_sym }
      else
        raise "Internal error: Unrecognized option: #{w}"
      end
    end
  end

  ##
  # Options to filter a list of datasets passed to OptionParser +opt+,
  # as determined by +what+ an Array with any combination of:
  # - :ref To filter by reference (--ref) or query (--no-ref)
  # - :multi To filter by multiple (--multi) or single (--no-multi) species
  # - :markers To filter by with (--markers) or without markers (--no-markers)
  # - :active To filter by active (--active) or inactive (--no-active)
  # - :taxonomy To filter by taxonomy (--taxonomy)
  # The "k-th" filter (--dataset-k) is always included
  def opt_filter_datasets(opt, what = %i[ref multi markers active taxonomy])
    what.each do |w|
      case w
      when :ref
        opt.on(
          '--[no-]ref',
          'Use only reference (or only non-reference) datasets'
        ) { |v| self[:ref] = v }
      when :multi
        opt.on(
          '--[no-]multi',
          'Use only multi-species (or only single-species) datasets'
        ) { |v| self[:multi] = v }
      when :markers
        opt.on(
          '--[no-]markers',
          'Use only datasets with (or without) markers'
        ) { |v| self[:markers] = v }
      when :active
        opt.on(
          '--[no-]active',
          'Use only active (or inactive) datasets'
        ) { |v| self[:active] = v }
      when :taxonomy
        opt.on(
          '-t', '--taxonomy RANK:TAXON',
          'Filter by taxonomy'
        ) { |v| self[:taxonomy] = MiGA::Taxonomy.new(v) }
      else
        raise "Internal error: Unrecognized option: #{w}"
      end
    end
    opt.on(
      '--ds-list FILE',
      'File containing a list of dataset names, one per line'
    ) { |v| self[:ds_list] = v }
    opt.on(
      '--dataset-k INTEGER', Integer,
      'Use only the k-th dataset in the list'
    ) { |v| self[:dataset_k] = v }
  end

  ##
  # Add a flag (true/false) to the OptionParser +opt+ defined by
  # +flag+ (without --) and +description+, and save it in the CLI as +sym+.
  # If +sym+ is nil, +flag+ is used as Symbol
  def opt_flag(opt, flag, description, sym = nil)
    sym = flag.to_sym if sym.nil?
    opt.on("--#{flag.to_s.tr('_', '-')}", description) { |v| self[sym] = v }
  end
end
