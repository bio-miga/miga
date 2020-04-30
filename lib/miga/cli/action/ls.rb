# @package MiGA
# @license Artistic-2.0

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
    end
  end

  def perform
    ds = cli.load_and_filter_datasets(cli[:silent])
    exit(ds.empty? ? 1 : 0) if cli[:silent]
    if !cli[:datum].nil?
      cli[:tabular] = true
      format_table(ds, [nil, nil]) { |d| [d.name, d.metadata[cli[:datum]]] }
    elsif !cli[:fields].nil?
      format_table(ds, [:name] + cli[:fields]) do |d|
        [d.name] + cli[:fields].map { |f| d.metadata[f] }
      end
    elsif cli[:info]
      format_table(ds, Dataset.INFO_FIELDS) { |d| d.info }
    elsif cli[:processing]
      comp = %w[- done queued]
      format_table(ds, [:name] + MiGA::Dataset.PREPROCESSING_TASKS) do |d|
        [d.name] + d.profile_advance.map { |i| comp[i] }
      end
    elsif cli[:taskstatus]
      format_table(ds, [:name] + MiGA::Dataset.PREPROCESSING_TASKS) do |d|
        [d.name] + d.results_status.values
      end
    else
      cli[:tabular] = true
      format_table(ds, [nil]) { |d| [d.name] }
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
