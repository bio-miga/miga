# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Summary < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { units: false, tabular: false }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
      cli.opt_filter_datasets(opt)
      cli.opt_object(opt, [:result_dataset])
      opt.on(
        '-o', '--output PATH',
        'Create output file instead of returning to STDOUT'
      ) { |v| cli[:output] = v }
      opt.on(
        '--tab',
        'Return a tab-delimited table'
      ) { |v| cli[:tabular] = v }
      opt.on(
        '--key STRING',
        'Return only the value of the requested key'
      ) { |v| cli[:key_md] = v }
      opt.on(
        '--with-units',
        'Include units in each cell'
      ) { |v| cli[:units] = v }
      opt.on(
        '--compute-and-save',
        'Compute and save the statistics if not yet available'
      ) { |v| cli[:compute] = v }
    end
  end

  def perform
    cli.ensure_par(result: '-r')
    ds = cli.load_and_filter_datasets
    cli.say 'Loading results'
    k = 0
    n = ds.size
    stats = ds.map do |d|
      cli.advance('Datasets:', k += 1, n, false)
      r = d.result(cli[:result])
      r.compute_stats if cli[:compute] && !r.nil? && r[:stats].empty?
      s = r.nil? ? {} : r[:stats]
      s.tap { |i| i[:dataset] = d.name }
    end
    cli.say ''
    keys = cli[:key_md].nil? ? stats.map(&:keys).flatten.uniq :
      [:dataset, cli[:key_md].downcase.miga_name.to_sym]
    keys.delete :dataset
    keys.unshift :dataset

    table = cli[:units] ?
      stats.map { |s|
        keys
          .map { |k| s[k].is_a?(Array) ? s[k].map(&:to_s).join('') : s[k] }
      } :
      stats.map { |s| keys.map { |k| s[k].is_a?(Array) ? s[k].first : s[k] } }
    io = cli[:output].nil? ? $stdout : File.open(cli[:output], 'w')
    cli.puts(io, MiGA.tabulate(keys, table, cli[:tabular]))
    io.close unless cli[:output].nil?
  end
end
