# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Console < MiGA::Cli::Action

  def parse_cli
  end

  def perform
    require 'irb'
    require 'irb/completion'
    IRB.start
  end

  def empty_action
  end
end
