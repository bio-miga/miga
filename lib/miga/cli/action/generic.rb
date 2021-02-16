# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Generic < MiGA::Cli::Action
  def parse_cli
    cli.opt_common = false
    cli.parse do |opt|
      descriptions = cli.class.TASK_DESC.keep_if { |k, v| k != :generic }
      opt.separator MiGA::MiGA.tabulate(
        [:action, :description], descriptions
      ).join("\n")
      opt.separator ''
      opt.separator 'generic options:'
      opt.on(
        '-h', '--help',
        'Display this screen'
      ) { puts opt; exit }
      opt.on(
        '-v', '--version',
        'Show MiGA version'
      ) { puts MiGA::MiGA.FULL_VERSION; exit }
      opt.on(
        '-V', '--long-version',
        'Show complete MiGA version'
      ) { |v| puts MiGA::MiGA.LONG_VERSION; exit }
      opt.on(
        '-C', '--citation',
        'How to cite MiGA'
      ) { |v| puts MiGA::MiGA.CITATION; exit }
    end
  end

  def perform
  end

  def complete
  end

  def name
    '{action}'
  end
end
