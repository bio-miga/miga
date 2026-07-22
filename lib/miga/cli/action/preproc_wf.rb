# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::PreprocWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  require 'miga/cli/action/add'
  include MiGA::Cli::Action::Wf

  def parse_cli
    default_opts_for_wf
    cli.defaults = { mytaxa: false, assembly: true }
    cli.parse do |opt|
      opt.on(
        '-i', '--input-type STRING',
        '(Mandatory) Type of input data, one of the following:',
        *MiGA::Cli::Action::Add.INPUT_TYPES.map { |k, v| "~ #{k}: #{v[0]}" }
      ) { |v| cli[:input_type] = v.downcase.to_sym }
      opt.on(
        '-m', '--mytaxa',
        'Perform MyTaxa/MyTaxa scan analyses'
      ) { |v| cli[:mytaxa] = v }
      opt.on(
        '--no-assembly',
        'Do not assemble the datasets or perform downstream analyses'
      ) { |v| cli[:assembly] = v }
      opts_for_wf(
        opt, 'Input files as defined by --input-type',
        multi: true, cleanup: false, ncbi: false, project_type: true
      )
    end
  end

  def perform
    # Input data
    cli.ensure_par(input_type: '-i')
    norun = %w[
      project_stats haai_distances aai_distances ani_distances clade_finding
    ]
    p_metadata = Hash[norun.map { |i| ["run_#{i}", false] }]
    d_metadata = { run_distances: false }
    cli[:mytaxa] = false unless cli[:assembly]
    unless cli[:mytaxa]
      d_metadata[:run_mytaxa_scan] = false
      d_metadata[:run_mytaxa] = false
    end
    unless cli[:assembly]
      %w[assembly cds essential_genes ssu].each do |i|
        d_metadata[:"run_#{i}"] = false
      end
    end
    p = create_project(cli[:input_type], p_metadata, d_metadata)

    # Run
    run_daemon
    summaries = []
    if cli[:input_type].to_s =~ /^raw_reads_/
      summaries += %w[raw_reads trimmed_reads]
    end
    summaries += %w[trimmed_fasta] if cli[:input_type].to_s =~ /^trimmed_reads_/
    summaries += %w[cds assembly essential_genes ssu] if cli[:assembly]
    summarize(summaries)
  end
end
