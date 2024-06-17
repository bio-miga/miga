# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Env < MiGA::Cli::Action
  def parse_cli
    cli.parse { |_| }
  end

  def perform
    puts <<~BASH
      export MIGA="#{MiGA::MiGA.root_path}"
      export MIGA_HOME=${MIGA_HOME:-"$HOME"}
      . "$MIGA_HOME/.miga_rc"
      # Ensure MiGA & submodules are first in PATH
      export PATH="$MIGA/bin:$PATH"
      for util in enveomics/Scripts FastAAI/fastaai multitrim ; do
        export PATH="$MIGA/utils/$util:$PATH"
      done
    BASH
  end

  def empty_action
  end
end
