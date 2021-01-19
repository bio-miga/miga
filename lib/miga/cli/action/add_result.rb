# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::AddResult < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { force: false }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt, :result])
      opt.on(
        '-f', '--force',
        'Force re-indexing of the result even if it\'s already registered'
      ) { |v| cli[:force] = v }
    end
  end

  def perform
    cli.ensure_par(result: '-r')
    obj = cli.load_project_or_dataset
    cli.say "Registering result: #{cli[:result]}"
    r = obj.add_result(cli[:result], true, force: cli[:force])
    raise 'Cannot add result, incomplete expected files' if r.nil?
  end
end
