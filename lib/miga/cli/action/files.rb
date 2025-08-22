# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Files < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { details: false, json: true }
    cli.parse do |opt|
      cli.opt_object(opt, %i[project dataset_opt result_opt])
      opt.on(
        '-i', '--info',
        'Print additional details for each file'
      ) { |v| cli[:details] = v }
      opt.on(
        '--[no-]json',
        'Include (or not) JSON files containing results metadata',
        'JSON files are included by default'
      ) { |v| cli[:json] = v }
    end
  end

  def perform
    obj = cli.load_project_or_dataset
    res = cli[:result] ? [cli.load_result] : cli.load_project_or_dataset.results
    res.each do |res|
      sym = res.key
      cli.puts "#{"#{sym}\tjson\t" if cli[:details]}#{res.path}" if cli[:json]
      res.each_file do |k, f|
        cli.puts "#{"#{sym}\t#{k}\t" if cli[:details]}#{res.dir}/#{f}"
      end
    end
  end
end
