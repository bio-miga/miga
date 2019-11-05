# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::QualityWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  include MiGA::Cli::Action::Wf

  def parse_cli
    cli.expect_files = true
    cli.defaults = {
      mytaxa: false, clean: false, regexp: MiGA::Cli.FILE_REGEXP,
      project_type: :genomes, dataset_type: :popgenome }
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
      opt.on(
        '-t', '--type STRING',
        "Type of datasets. Recognized types include:",
        *MiGA::Dataset.KNOWN_TYPES
          .map { |k, v| "~ #{k}: #{v[:description]}" unless v[:multi] }
      ) { |v| cli[:dataset_type] = v.downcase.to_sym }
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
    %w[cds assembly essential_genes ssu].each do |r|
      call_cli([
        'summary',
        '-P', cli[:outdir],
        '-r', r,
        '-o', File.expand_path("#{r}.tsv", cli[:outdir]),
        '--tab'
      ])
    end
    if cli[:mytaxa]
      dir = File.expand_path('mytaxa_scan', cli[:outdir])
      Dir.mkdir(dir)
      p.each_dataset do |d|
        r = d.result(:mytaxa_scan) or next
        f = r.file_path(:report) or next
        FileUtils.cp(f, dir)
      end
    end
    # Cleanup (if --clean)
    if cli[:clean]
      %w[data daemon metadata miga.project.json].each do |f|
        FileUtils.rm_rf(File.expand_path(f, cli[:outdir]))
      end
    end
  end
end
