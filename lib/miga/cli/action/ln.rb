# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Ln < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { info: false, force: false, method: :hardlink }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt])
      opt.on(
        '-Q', '--project-target PATH',
        '(Mandatory) Path to the project where to link the dataset'
      ) { |v| cli[:project2] = v }
      opt.on(
        '-f', '--force',
        'Force linking, even if dataset\'s preprocessing is incomplete'
      ) { |v| cli[:force] = v }
      opt.on(
        '-s', '--symlink',
        'Create symlinks instead of the default hard links'
      ) { cli[:method] = :symlink }
      opt.on(
        '-c', '--copy',
        'Create copies instead of the default hard links'
      ) { cli[:method] = :copy }
      cli.opt_filter_datasets(opt)
    end
  end

  def perform
    p = cli.load_project
    q = cli.load_project(:project2, '-Q')
    ds = cli.load_and_filter_datasets
    ds.each do |d|
      next unless cli[:force] or d.done_preprocessing?

      cli.puts d.name
      q.import_dataset(d, cli[:method])
    end
  end
end
