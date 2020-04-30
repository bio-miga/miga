# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::About < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { info: false, processing: false, tabular: false }
    cli.parse do |opt|
      cli.opt_object(opt, [:project])
      opt.on(
        '-p', '--processing',
        'Print information on processing advance'
      ) { |v| cli[:processing] = v }
      opt.on(
        '-m', '--metadata STRING',
        'Print name and metadata field only'
      ) { |v| cli[:datum] = v }
      opt.on(
        '--tab',
        'Return a tab-delimited table'
      ) { |v| cli[:tabular] = v }
    end
  end

  def perform
    p = cli.load_project
    if not cli[:datum].nil?
      v = p.metadata[cli[:datum]]
      cli.puts v.nil? ? '?' : v
    elsif cli[:processing]
      keys = Project.DISTANCE_TASKS + Project.INCLADE_TASKS
      cli.puts MiGA.tabulate([:task, :status], keys.map do |k|
        [k, p.add_result(k, false).nil? ? 'queued' : 'done']
      end, cli[:tabular])
    else
      cli.puts MiGA.tabulate([:key, :value], p.metadata.data.keys.map do |k|
        v = p.metadata[k]
        [k, k == :datasets ? v.size : v]
      end, cli[:tabular])
    end
  end
end
