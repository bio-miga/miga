# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::QualityWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  include MiGA::Cli::Action::Wf

  def parse_cli
    default_opts_for_wf
    cli.defaults = { mytaxa: false, min_qual: 'no' }
    cli.parse do |opt|
      opt.on(
        '-m', '--mytaxa-scan',
        'Perform MyTaxa scan analysis'
      ) { |v| cli[:mytaxa] = v }
      opts_for_wf(opt, 'Input genome assemblies (nucleotides, FastA)')
    end
  end

  def perform
    # Input data
    norun = %w[
      project_stats haai_distances aai_distances ani_distances clade_finding
    ]
    p_metadata = Hash[norun.map { |i| ["run_#{i}", false] }]
    d_metadata = { run_distances: false }
    d_metadata[:run_mytaxa_scan] = false unless cli[:mytaxa]
    p = create_project(:assembly, p_metadata, d_metadata)
    # Run
    run_daemon
    summarize
    if cli[:mytaxa]
      dir = File.expand_path('mytaxa_scan', cli[:outdir])
      Dir.mkdir(dir)
      p.each_dataset do |d|
        r = d.result(:mytaxa_scan) or next
        f = r.file_path(:report) or next
        FileUtils.cp(f, dir)
      end
    end
    cleanup
  end
end
