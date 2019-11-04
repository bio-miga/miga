# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::QualityWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  include MiGA::Cli::Action::Wf

  def parse_cli
    cli.expect_files = true
    cli.defaults = {
      mytaxa: false, clean: false, regexp: MiGA::Cli.FILE_REGEXP }
    cli.parse do |opt|
      opt.on(
        '-o', '--out_dir PATH',
        'Directory to be created with all output data'
      ) { |v| cli[:outdir] = v }
      opt.on(
        '-m', '--mytaxa_scan',
        'Perform MyTaxa scan analysis'
      ) { |v| cli[:mytaxa] = v }
      opt.on(
        '-c', '--clean',
        'Clean all intermediate files after generating the reports'
      ) { |v| cli[:clean] = v }
      opt.on(
        '-R', '--name-regexp REGEXP', Regexp,
        'Regular expression indicating how to extract the name from the path',
        "By default: '#{cli[:regexp]}'"
      ) { |v| cli[:regexp] = v }
      opts_for_wf(opt, 'Input genome assemblies (nucleotides, FastA)')
    end
  end

  def perform
    p = create_project(:assembly)
    # TODO: Add metadata flags to control workflow
    # TODO: Run daemon
    # TODO: Extract summaries
    # TODO: Cleanup (if --clean)
  end
end
