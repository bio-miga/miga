# frozen_string_literal: true

require 'miga/cli/action'

class MiGA::Cli::Action::Ls < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { info: false, processing: false, silent: false }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
      cli.opt_filter_datasets(opt)
      opt.on(
        '-i', '--info',
        'Print additional information on each dataset'
      ) { |v| cli[:info] = v }
      opt.on(
        '-p', '--processing',
        'Print information on processing advance'
      ) { |v| cli[:processing] = v }
      opt.on(
        '-t', '--task-status',
        'Print the status of each processing step'
      ) { |v| cli[:taskstatus] = v }
      opt.on(
        '-m', '--metadata STRING',
        'Print name and metadata field only',
        'If set, ignores --info and forces --tab (without header)'
      ) { |v| cli[:datum] = v }
      opt.on(
        '-f', '--fields STR1,STR2,STR3', Array,
        'Comma-delimited metadata fields to print'
      ) { |v| cli[:fields] = v }
      opt.on(
        '--tab',
        'Return a tab-delimited table'
      ) { |v| cli[:tabular] = v }
      opt.on(
        '-o', '--output PATH',
        'Create output file instead of returning to STDOUT'
      ) { |v| cli[:output] = v }
      opt.on(
        '-s', '--silent',
        'No output and exit with non-zero status if the dataset list is empty'
      ) { |v| cli[:silent] = v }
      opt.on(
        '--exec CMD',
        'Command to execute per dataset, with the following token variables:',
        '~ {{dataset}}: Name of the dataset',
        '~ {{project}}: Path to the project'
      ) { |v| cli[:exec] = v }
    end
  end

  def perform
    ds = cli.load_and_filter_datasets(cli[:silent])
    p  = cli.load_project
    exit(ds.empty? ? 1 : 0) if cli[:silent]

    head = nil
    fun  = nil
    if cli[:datum]
      cli[:tabular] = true
      head = [nil, nil]
      fun  = proc { |d| [d.name, d.metadata[cli[:datum]]] }
    elsif cli[:fields]
      head = [:name] + cli[:fields]
      fun  = proc { |d| [d.name] + cli[:fields].map { |f| d.metadata[f] } }
    elsif cli[:info]
      head = Dataset.INFO_FIELDS
      fun  = proc(&:info)
    elsif cli[:processing]
      head = [:name] + MiGA::Dataset.PREPROCESSING_TASKS
      fun  = proc do |d|
        [d.name] + d.profile_advance.map { |i| %w[- done queued][i] }
      end
    elsif cli[:taskstatus]
      head = [:name] + MiGA::Dataset.PREPROCESSING_TASKS
      fun  = proc { |d| [d.name] + d.results_status.values }
    else
      cli[:tabular] = true
      head = [nil]
      fun  = proc { |d| [d.name] }
    end

    format_table(ds, head) do |d|
      if cli[:exec]
        MiGA::MiGA.run_cmd(
          cli[:exec].miga_variables(dataset: d.name, project: p.path)
        )
      end
      fun[d]
    end
  end

  private

  def format_table(ds, header, &blk)
    io = cli[:output].nil? ? $stdout : File.open(cli[:output], 'w')
    cli.say 'Collecting metadata'
    k = 0
    cli.table(
      header,
      ds.map do |d|
        cli.advance('Datasets:', k += 1, ds.size, false)
        blk[d]
      end,
      io
    )
    cli.say ''
    io.close unless cli[:output].nil?
  end
end
