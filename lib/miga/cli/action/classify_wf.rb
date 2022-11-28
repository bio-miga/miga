# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::ClassifyWf < MiGA::Cli::Action
  require 'miga/cli/action/wf'
  include MiGA::Cli::Action::Wf

  def parse_cli
    default_opts_for_wf
    cli.defaults = {
      download: false, summaries: true, pvalue: 0.05,
      local: File.expand_path('.miga_db', ENV['MIGA_HOME'])
    }
    cli.parse do |opt|
      opt.on(
        '--download-db',
        'Attempt to download the reference database (all default options)',
        'It is recommended to use "miga get_db" separately instead'
      ) { |v| cli[:download] = v }
      opt.on(
        '-n', '--database STRING',
        'Name of the reference database to use',
        'By default, the first locally listed database is used'
      ) { |v| cli[:database] = v.to_sym }
      opt.on(
        '-p', '--p-value FLOAT', Float,
        'Maximum p-value to transfer taxonomy',
        "By default: #{cli[:pvalue]}"
      ) { |v| cli[:pvalue] = v }
      opt.on(
        '-l', '--local-dir PATH',
        "Local directory to store the database. By default: #{cli[:local]}"
      ) { |v| cli[:local] = v }
      opt.on(
        '--db-path STRING',
        'Path to the reference database to use, a fully indexed MiGA project',
        'If defined, --local-dir and --database are ignored'
      ) { |v| cli[:db_path] = v }
      opt.on(
        '--no-summaries',
        'Do not generate intermediate step summaries'
      ) { |v| cli[:summaries] = v }
      opts_for_wf(opt, 'Input genome assemblies (nucleotides, FastA)')
    end
  end

  def perform
    # Input data
    ref_db = reference_db
    norun = %w[
      haai_distances aai_distances ani_distances clade_finding
    ]
    p_metadata = Hash[norun.map { |i| ["run_#{i}", false] }]
    p = create_project(
      :assembly,
      p_metadata,
      run_mytaxa_scan: false, run_distances: false
    )
    p.set_option(:ref_project, ref_db.path)
    p.set_option(:tax_pvalue, cli[:pvalue])

    # Run
    run_daemon
    summarize(%w[cds assembly essential_genes]) if cli[:summaries]
    summarize(%w[taxonomy])
    unless cli[:prepare_and_exit]
      cli.say "Summary: classification"
      ofile = File.expand_path('classification.tsv', cli[:outdir])
      call_cli(['ls', '-P', cli[:outdir], '-m', 'tax', '--tab', '-o', ofile])
    end
    cleanup
  end

  private

  def reference_db
    cli.say "Locating reference database"
    ref_db_path = cli[:db_path]
    if ref_db_path.nil?
      if cli[:download]
        get_db_call  = ['get_db', '-l', cli[:local]]
        get_db_call += ['-n', cli[:database]] unless cli[:database].nil?
        call_cli(get_db_call)
      end
      if cli[:database].nil?
        lm_f = File.expand_path('_local_manif.json', cli[:local])
        unless File.size? lm_f
          raise 'No locally listed databases, call "miga get_db" first'
        end

        cli[:database] = MiGA::Json.parse(lm_f)[:databases].keys.first
      end
      ref_db_path = File.expand_path(cli[:database].to_s, cli[:local])
    end
    ref_db = MiGA::Project.load(ref_db_path)
    raise "Cannot locate reference database: #{ref_db_path}" if ref_db.nil?

    cli.say "Reference database: #{ref_db.name}"
    ref_db
  end
end
