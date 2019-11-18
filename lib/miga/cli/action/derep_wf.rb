# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::DerepWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  include MiGA::Cli::Action::Wf

  def parse_cli
    default_opts_for_wf
    cli.defaults = {
      metric: :ani, threshold: 95.0, criterion: :quality,
      summaries: true, collection: true
    }
    cli.parse do |opt|
      opt.on(
        '--aai',
        'Use Average Amino Acid Identity (AAI) as genome similarity metric',
        'By default: Use Average Nucleotide Identity (ANI)'
      ) { cli[:metric] = :aai }
      opt.on(
        '--threshold FLOAT', Float,
        "Metric threshold (%) to dereplicate. By default: #{cli[:threshold]}"
      ) { |v| cli[:threshold] = v }
      opt.on(
        '--medoids',
        'Use medoids as clade representatives',
        'By default: Use genome with the highest quality'
      ) { |v| cli[:criterion] = :medoids }
      opt.on(
        '--no-collection',
        'Do not generate a dereplicated collection of assemblies'
      ) { |v| cli[:collection] = v }
      opt.on(
        '--no-summaries',
        'Do not generate intermediate step summaries'
      ) { |v| cli[:summaries] = v }
      opts_for_wf_distances(opt)
      opts_for_wf(opt, 'Input genome assemblies (nucleotides, FastA)')
    end
  end

  def perform
    # Input data
    p = create_project(:assembly)
    unless cli[:threshold] >= 0.0 && cli[:threshold] <= 100.0
      raise "The threshold of identity must be in the range [0,100]"
    end
    # Customize pipeline
    p.each_dataset do |d|
      d.metadata[:run_mytaxa_scan] = false
      d.metadata[:run_ssu] = false
      d.save
    end
    p.metadata[:run_project_stats] = false
    p.metadata[:run_clades] = false
    p.metadata[:gsp_metric] = cli[:metric]
    p.metadata["gsp_#{cli[:metric]}"] = cli[:threshold]
    p.save
    # Run
    run_daemon
    dereplicate(p)
    # Summarize
    if cli[:summaries]
      %w[cds assembly essential_genes].each do |r|
        call_cli([
          'summary',
          '-P', cli[:outdir],
          '-r', r,
          '-o', File.expand_path("#{r}.tsv", cli[:outdir]),
          '--tab'
        ])
      end
    end
    # Cleanup (if --clean)
    if cli[:clean]
      %w[data daemon metadata miga.project.json].each do |f|
        FileUtils.rm_rf(File.expand_path(f, cli[:outdir]))
      end
    end
  end

  private

  def dereplicate(p)
    cli.say "Extracting genomospecies clades"
    r = p.result(:clade_finding) or raise "Result unavailable: run failed"
    c_f = r.file_path(:clades_gsp) or raise 'Result incomplete: run failed'
    clades = File.readlines(c_f).map { |i| i.chomp.split("\t") }
    rep = representatives(p)
    File.open(File.expand_path('genomospecies.tsv', cli[:outdir]), 'w') do |fh|
      fh.puts "Clade\tRepresentative\tMembers"
      clades.each_with_index do |i, k|
        fh.puts ["gsp_#{k+1}", rep[k], i.join(',')].join("\t")
      end
    end
    if cli[:collection]
      dir = File.expand_path('representatives', cli[:outdir])
      FileUtils.mkdir_p(dir)
      rep.each do |i|
        f = p.dataset(i).result(:assembly).file_path(:largecontigs)
        FileUtils.cp(f, dir)
      end
    end
  end

  def representatives(p)
    cli.say "Identifying representatives"
    f = File.expand_path('representatives.txt', cli[:outdir])
    if cli[:criterion] == :medoids
      FileUtils.cp(p.result(:clade_finding).file_path(:medoids_gsp), f)
    else
      src = File.expand_path('utils/representatives.rb', MiGA::MiGA.root_path)
      `ruby '#{src}' '#{p.path}' | cut -f 2 > '#{f}'`
    end
    File.readlines(f).map(&:chomp)
  end
end
