# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Rm < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { remove: false }
    cli.parse do |opt|
      cli.opt_object(opt)
      opt.on(
        '-r', '--remove',
        'Also remove all associated files',
        'By default, only unlinks from metadata'
      ) { |v| cli[:remove] = v }
    end
  end

  def perform
    d = cli.load_dataset
    cli.load_project.unlink_dataset(d.name)
    d.remove! if cli[:remove]
  end
end
