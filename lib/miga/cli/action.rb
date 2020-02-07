# @package MiGA
# @license Artistic-2.0

require 'miga/cli'

##
# An action to be performed by the CLI. This is a generic class to be extended
# by MiGA::Cli::Action::* classes. Do not attempt creating directly with +new+,
# use instead the MiGA::Cli::Action.load interface.
class MiGA::Cli::Action < MiGA::MiGA

  class << self
    def load(task, cli)
      require "miga/cli/action/#{task}"
      camel = task.to_s.gsub(/(?:_|^)(\S)/, &:upcase).delete('_')
      klass = Object.const_get("MiGA::Cli::Action::#{camel}")
      klass.new(cli)
    end
  end

  attr_accessor :cli

  def initialize(cli)
    @cli = cli
  end

  ##
  # Launch the sequence
  def launch
    MiGA.DEBUG 'Cli::Action.launch'
    empty_action if cli.argv.empty?
    parse_cli
    perform
    complete
  end

  ##
  # Parse the CLI object
  def parse_cli
    raise "Undefined interface for the command line of #{cli.task}"
  end

  ##
  # Perform the action
  def perform
    raise "Undefined action for the command line of #{cli.task}"
  end

  ##
  # Complete the action
  def complete
    cli.say 'Done'
  end

  ##
  # Name of the action, as referred to by the CLI
  def name
    camel = self.class.to_s.gsub(/.*::/,'')
    camel.gsub(/(\S)([A-Z])/,'\1_\2').downcase
  end

  ##
  # What to do when cli.argv is empty
  def empty_action
    cli.argv << '-h'
  end
end
