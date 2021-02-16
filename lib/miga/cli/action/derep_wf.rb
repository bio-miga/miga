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
        '--ani',
        'Use Average Nucleotide Identity (ANI) as similarity metric (default)'
      ) { cli[:metric] = :ani }
      opt.on(
        '--threshold FLOAT', Float,
        "Metric threshold (%) to dereplicate. By default: #{cli[:threshold]}"
      ) { |v| cli[:threshold] = v }
      opt.on(
        '--quality',
        'Use genome with highest quality as clade representatives (default)'
      ) { |v| cli[:criterion] = :quality }
      opt.on(
        '--medoids',
        'Use medoids as clade representatives'
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
    p = create_project(
      :assembly,
      { run_project_stats: false, run_clades: false },
      { run_mytaxa_scan: false, run_ssu: false }
    )
    p.set_option(:gsp_metric, cli[:metric])
    p.set_option(:"gsp_#{cli[:metric]}", cli[:threshold])

    # Run
    run_daemon
    dereplicate(p)
    summarize(%w[cds assembly essential_genes]) if cli[:summaries]
    cleanup
  end

  private

  def dereplicate(p)
    cli.say 'Extracting genomospecies clades'
    r = p.result(:clade_finding) or raise 'Result unavailable: run failed'
    c_f = r.file_path(:clades_gsp) or raise 'Result incomplete: run failed'
    clades = File.readlines(c_f).map { |i| i.chomp.split("\t") }
    rep = representatives(p)
    File.open(File.expand_path('genomospecies.tsv', cli[:outdir]), 'w') do |fh|
      fh.puts "Clade\tRepresentative\tMembers"
      clades.each_with_index do |i, k|
        fh.puts ["gsp_#{k + 1}", rep[k], i.join(',')].join("\t")
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
    cli.say 'Identifying representatives'
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
