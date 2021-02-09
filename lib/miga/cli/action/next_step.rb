# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::NextStep < MiGA::Cli::Action
  def parse_cli
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
    end
  end

  def perform
    obj = cli.load_project_or_dataset
    n = obj.next_task
    cli.puts(n || '?')
  end
end
