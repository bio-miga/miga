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
        ){ |v| cli[:metadata] = v }
    end
  end

  def perform
    obj = cli.load_project_or_dataset
    cli.add_metadata(obj)
    obj.save
  end
end
