# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::QualityWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  include MiGA::Cli::Action::Wf

  def parse_cli
    default_opts_for_wf
    cli.defaults = { mytaxa: false }
    cli.parse do |opt|
      opt.on(
        '-m', '--mytaxa_scan',
        'Perform MyTaxa scan analysis'
      ) { |v| cli[:mytaxa] = v }
      opts_for_wf(opt, 'Input genome assemblies (nucleotides, FastA)')
    end
  end

  def perform
    # Input data
    p = create_project(:assembly)
    # Customize pipeline
    p.each_dataset do |d|
      d.metadata[:run_mytaxa_scan] = false unless cli[:mytaxa]
      d.metadata[:run_distances] = false
      d.save
    end
    %w[
      project_stats haai_distances aai_distances ani_distances clade_finding
    ].each { |r| p.metadata["run_#{r}"] = false }
    p.save
    # Run
    run_daemon
    # Summarize
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
