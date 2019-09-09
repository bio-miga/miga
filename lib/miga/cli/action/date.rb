# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Date < MiGA::Cli::Action

  def parse_cli
    cli.parse { |_| }
  end

  def perform
    puts Time.now.to_s
  end

  def empty_action
  end
end
