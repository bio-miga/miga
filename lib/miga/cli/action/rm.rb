# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Rm < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { remove: false }
    cli.parse do |opt|
      cli.opt_object(opt, %i[project dataset_opt result_opt])
      opt.on(
        '-R', '--remove',
        'Also remove all associated files',
        'By default, only unlinks from metadata'
      ) { |v| cli[:remove] = v }
    end
  end

  def perform
    if cli[:result] && r = cli.load_result
      cli[:remove] ? r.remove! : r.unlink
    elsif d = cli.load_dataset
      cli.load_project.unlink_dataset(d.name)
      d.remove! if cli[:remove]
    else
      raise "You must define one of --result or --dataset"
    end
  end
end
