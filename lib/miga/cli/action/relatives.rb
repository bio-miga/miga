# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Relatives < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { metric: :aai, external: false, how_many: 5 }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
      cli.opt_filter_datasets(opt)
      opt.on(
        '--metric STRING',
        'Use this metric of identity, one of ANI or AAI (default)'
      ) { |v| cli[:metric] = v.downcase.to_sym }
      opt.on(
        '--ref-project',
        'Report distances to the external reference project used for taxonomy',
        'By default: report distances to other datasets in the project'
      ) { |v| cli[:external] = v }
      opt.on(
        '-n', '--how-many INT', Integer,
        'Number of top values to report'
      ) { |v| cli[:how_many] = v }
      opt.on(
        '--tab',
        'Return a tab-delimited table'
      ) { |v| cli[:tabular] = v }
      opt.on(
        '-o', '--output PATH',
        'Create output file instead of returning to STDOUT'
      ) { |v| cli[:output] = v }
    end
  end

  def perform
    cr = []
    cli.load_and_filter_datasets.each do |d|
      d_cr = d.closest_relatives(cli[:how_many], cli[:external], cli[:metric])
      d_cr ||= []
      cr += d_cr.map { |i| [d.name] + i }
    end
    io = cli[:output].nil? ? $stdout : File.open(cli[:output], 'w')
    cli.table(['dataset_A', 'dataset_B', cli[:metric]], cr, io)
  end
end
