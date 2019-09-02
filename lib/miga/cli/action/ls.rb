# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Ls < MiGA::Cli::Action

  def parse_cli
    cli.defaults = {info: false, processing: false, silent: false}
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
      cli.opt_filter_datasets(opt)
      opt.on(
        '-i', '--info',
        'Print additional information on each dataset'
        ){ |v| cli[:info] = v }
      opt.on(
        '-p', '--processing',
        'Print information on processing advance'
        ){ |v| cli[:processing] = v }
      opt.on(
        '-m', '--metadata STRING',
        'Print name and metadata field only',
        'If set, ignores -i and assumes --tab'
        ){ |v| cli[:datum] = v }
      opt.on(
        '--tab',
        'Return a tab-delimited table'
        ){ |v| cli[:tabular] = v }
      opt.on(
        '-s', '--silent',
        'No output and exit with non-zero status if the dataset list is empty'
        ){ |v| cli[:silent] = v }
    end
  end

  def perform
    ds = cli.load_and_filter_datasets
    exit(ds.empty? ? 1 : 0) if cli[:silent]
    if !cli[:datum].nil?
      ds.each do |d|
        v = d.metadata[cli[:datum]]
        puts "#{d.name}\t#{v.nil? ? '?' : v}"
      end
    elsif cli[:info]
      cli.table(Dataset.INFO_FIELDS, ds.map { |d| d.info })
    elsif cli[:processing]
      comp = %w[- done queued]
      cli.table([:name] + MiGA::Dataset.PREPROCESSING_TASKS,
        ds.map { |d| [d.name] + d.profile_advance.map { |i| comp[i] } })
    else
      ds.each { |d| cli.puts d.name }
    end
  end
end
