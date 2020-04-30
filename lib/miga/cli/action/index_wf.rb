# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::IndexWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  include MiGA::Cli::Action::Wf

  def parse_cli
    default_opts_for_wf
    cli.defaults = { mytaxa: false }
    cli.parse do |opt|
      opt.on(
        '-m', '--mytaxa-scan',
        'Perform MyTaxa scan analysis'
      ) { |v| cli[:mytaxa] = v }
      opts_for_wf_distances(opt)
      opts_for_wf(opt, 'Input genome assemblies (nucleotides, FastA)',
                  cleanup: false, project_type: true)
    end
  end

  def perform
    # Input data
    p = create_project(:assembly, {}, run_mytaxa_scan: cli[:mytaxa])
    # Run
    run_daemon
    summarize
  end
end
