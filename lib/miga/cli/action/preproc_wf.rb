# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::PreprocWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  require 'miga/cli/action/add'
  include MiGA::Cli::Action::Wf

  def parse_cli
    default_opts_for_wf
    cli.defaults = { mytaxa: false }
    cli.parse do |opt|
      opt.on(
        '-i', '--input-type STRING',
        '(Mandatory) Type of input data, one of the following:',
        *MiGA::Cli::Action::Add.INPUT_TYPES.map{ |k,v| "~ #{k}: #{v[0]}" }
      ) { |v| cli[:input_type] = v.downcase.to_sym }
      opt.on(
        '-m', '--mytaxa_scan',
        'Perform MyTaxa scan analysis'
      ) { |v| cli[:mytaxa] = v }
      opts_for_wf(opt, 'Input files as defined by --input-type',
        multi: true, cleanup: false, ncbi: false)
    end
  end

  def perform
    # Input data
    cli.ensure_par(input_type: '-i')
    p_metadata = Hash[
      %w[project_stats haai_distances aai_distances ani_distances clade_finding]
        .map { |i| ["run_#{i}", false] }
    ]
    d_metadata = { run_distances: false }
    unless cli[:mytaxa]
      d_metadata[:run_mytaxa_scan] = false
      d_metadata[:run_mytaxa] = false
    end
    p = create_project(cli[:input_type], p_metadata, d_metadata)
    # Run
    run_daemon
    summarize
  end
end
