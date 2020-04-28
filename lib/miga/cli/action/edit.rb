# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Edit < MiGA::Cli::Action

  def parse_cli
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
      opt.on(
        '-m', '--metadata STRING',
        'Metadata as key-value pairs separated by = and delimited by comma',
        'Values are saved as strings except for booleans (true / false) or nil'
      ) { |v| cli[:metadata] = v }
      opt.on(
        '--activate',
        'Activate dataset; requires -D'
      ) { |v| cli[:activate] = v }
      opt.on(
        '--inactivate',
        'Inactivate dataset; requires -D'
      ) { |v| cli[:activate] = !v }
    end
  end

  def perform
    obj = cli.load_project_or_dataset
    unless cli[:activate].nil?
      cli.ensure_par({ dataset: '-D' },
        '%<name>s is mandatory with --[in-]activate: please provide %<flag>s')
      cli[:activate] ? obj.activate! : obj.inactivate!
    end
    cli.add_metadata(obj)
    obj.save
  end
end
