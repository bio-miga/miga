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
    p = cli.load_project
    n = nil
    if cli[:dataset].nil?
      n = p.next_distances(false)
      n ||= p.next_inclade(false)
    else
      d = cli.load_dataset
      n = d.next_preprocessing if d.is_active?
    end
    n ||= '?'
    cli.puts n
  end
end
