# @package MiGA
# @license Artistic-2.0

##
# Helper module for workflows
module MiGA::Cli::Action::Wf
  def default_opts_for_wf
    cli.expect_files = true
    cli.defaults = {
      clean: false, project_type: :genomes, dataset_type: :popgenome,
      ncbi_draft: true, ncbi_ref: false,
      min_qual: MiGA::Project.OPTIONS[:min_qual][:default],
      prepare_and_exit: false
    }
  end

  def opts_for_wf(opt, files_desc, params = {})
    {
      multi: false, cleanup: true, project_type: false, ncbi: true, qual: true
    }.each { |k, v| params[k] = v if params[k].nil? }
    opt.on(
      '-o', '--out_dir PATH',
      '(Mandatory) Directory to be created with all output data'
    ) { |v| cli[:outdir] = v }
    opt.on(
      '-P', '--project PATH',
      '::HIDE::' # Applying the principle of least surprise, alias of -o
    ) { |v| cli[:outdir] = v }
    opt.separator ''
    opt.separator "    FILES...: #{files_desc}"
    opt.separator ''
    opt.separator 'Workflow Control Options'
    opt.on(
      '-C', '--collection STRING',
      'Collection of essential genes to use as reference',
      'One of: dupont_2012 (default), lee_2019'
    ) { |v| cli[:ess_coll] = v }
    if params[:ncbi]
      opt.on(
        '-T', '--ncbi-taxon STRING',
        'Download all the genomes in NCBI classified as this taxon'
      ) { |v| cli[:ncbi_taxon] = v }
      opt.on(
        '--no-draft', '::HIDE::' # Deprecated
      ) { |v| cli[:ncbi_draft] = v }
      opt.on(
        '--ncbi-complete',
        'Only download complete genomes, not drafts (requires -T)'
      ) { |v| cli[:ncbi_draft] = !v }
      opt.on(
        '--ncbi-ref',
        'Only download RefSeq reference genomes (requires -T)'
      ) { |v| cli[:ncbi_ref] = v }
      opt.on(
        '-G', '--gtdb-taxon STRING',
        'Download all the genomes in GTDB classified as this taxon'
      ) { |v| cli[:gtdb_taxon] = v }
      opt.on(
        '--gtdb-ref',
        'Only download reference anchor genomes in GTDB (requires -G)'
      ) { |v| cli[:gtdb_ref] = v }
      opt.on(
        '-S', '--seqcode-type',
        'Download all type genomes from the SeqCode Registry'
      ) { |v| cli[:seqcode_type] = v }
      opt.on(
        '--max-download INT', Integer,
        'Maximum number of genomes to download (by default: unlimited)',
        'It applies independently to -T, -G and --S'
      ) { |v| cli[:max_download] = v }
    end
    if params[:qual]
      opt.on(
        '--min-qual FLOAT',
        'Minimum genome quality to include in analysis',
        "By default: #{cli[:min_qual]}"
      ) { |v| cli[:min_qual] = v == 'no' ? v : v.to_f }
    end
    if params[:cleanup]
      opt.on(
        '-c', '--clean',
        'Clean all intermediate files after generating the reports'
      ) { |v| cli[:clean] = v }
    end
    opt.on(
      '-R', '--name-regexp REGEXP', Regexp,
      'Regular expression indicating how to extract the name from the path',
      "By default: '#{MiGA::Cli.FILE_REGEXP}'"
    ) { |v| cli[:regexp] = v }
    opt_object_type(opt, :dataset, params[:multi])
    opt_object_type(opt, :project, params[:multi]) if params[:project_type]
    opt.on(
      '--daemon PATH',
      'Use custom daemon configuration in JSON format',
      'By default: ~/.miga_daemon.json'
    ) { |v| cli[:daemon_json] = v }
    opt.on(
      '-j', '--jobs INT', Integer,
      'Number of parallel jobs to execute',
      'By default controlled by the daemon configuration (maxjobs)'
    ) { |v| cli[:jobs] = v }
    opt.on(
      '-t', '--threads INT', Integer,
      'Number of CPUs to use per job',
      'By default controlled by the daemon configuration (ppn)'
    ) { |v| cli[:threads] = v }
    opt.on(
      '--threads-project INT', Integer,
      'Number of CPUs to use per project-wide job',
      'By default controlled by the daemon configuration (ppn_project or ppn)'
    ) { |v| cli[:threads_project] = v }
    opt.on(
      '--prepare-and-exit',
      'Create project and import datasets, but do not run any analyses'
    ) { |v| cli[:prepare_and_exit] = v }
  end

  def opts_for_wf_distances(opt)
    opt.on('--sensitive', 'Alias to: --aai-p blast+ --ani-p blast+') do
      cli[:aai_p] = 'blast+'
      cli[:ani_p] = 'blast+'
    end
    opt.on('--fast', 'Alias to: --aai-p diamond --ani-p fastani (default)') do
      cli[:aai_p] = 'diamond'
      cli[:ani_p] = 'fastani'
    end
    opt.on(
      '--only-ani', 'Alias to: --haai-p no --aai-p no',
      'Use only for collections with expected AAI around or above 85%'
    ) do
      cli[:haai_p] = 'no'
      cli[:aai_p] = 'no'
    end
    opt.on(
      '--haai-p STRING',
      'hAAI search engine. One of: blast+, fastaai, blat, diamond, fastaai, no',
      'The default is "no" for clade projects and "fastaai" otherwise'
    ) { |v| cli[:haai_p] = v }
    opt.on(
      '--aai-p STRING',
      'AAI search engine. One of: blast+, blat, diamond (default), no'
    ) { |v| cli[:aai_p] = v }
    opt.on(
      '--ani-p STRING',
      'ANI search engine. One of: blast+, blat, fastani (default)'
    ) { |v| cli[:ani_p] = v }
  end

  def create_project(stage, p_metadata = {}, d_metadata = {})
    cli.ensure_par(
      outdir: '-o',
      project_type: '--project-type',
      dataset_type: '--dataset-type'
    )
    paired = cli[:input_type].to_s.include?('_paired')
    cli[:regexp] ||= MiGA::Cli.FILE_REGEXP(paired)

    # Create empty project and populate with datasets
    p = initialize_empty_project(p_metadata)
    download_datasets
    import_datasets(stage)

    # Define datasets metadata
    p.load
    d_metadata[:type] = cli[:dataset_type]
    p.each_dataset { |d| transfer_metadata(d, d_metadata) }
    p
  end

  def initialize_empty_project(metadata)
    call_cli(
      ['new', '-P', cli[:outdir], '-t', cli[:project_type]]
    ) unless MiGA::Project.exist? cli[:outdir]

    # Define project metadata
    p = cli.load_project(:outdir, '-o')
    metadata[:type] = cli[:project_type]
    transfer_metadata(p, metadata)
    %i[haai_p aai_p ani_p ess_coll min_qual].each do |i|
      p.set_option(i, cli[i])
    end
    p
  end

  def download_datasets
    # Download datasets from NCBI
    unless cli[:ncbi_taxon].nil?
      what = cli[:ncbi_ref] ? '--reference' :
             cli[:ncbi_draft] ? '--all' : '--complete'
      cmd = ['ncbi_get', '-P', cli[:outdir], '-T', cli[:ncbi_taxon], what]
      cmd += ['--max', cli[:max_download]] if cli[:max_download]
      call_cli(cmd)
    end

    # Download datasets from GTDB
    unless cli[:gtdb_taxon].nil?
      cmd = ['gtdb_get', '-P', cli[:outdir], '-T', cli[:gtdb_taxon]]
      cmd << '--reference' if cli[:gtdb_ref]
      cmd += ['--max', cli[:max_download]] if cli[:max_download]
      call_cli(cmd)
    end

    # Download datasets from SeqCode Registry
    if cli[:seqcode_type]
      cmd = ['seqcode_get', '-P', cli[:outdir]]
      cmd += ['--max', cli[:max_download]] if cli[:max_download]
      call_cli(cmd)
    end
  end

  def import_datasets(stage)
    call_cli(
      [
        'add',
        '--ignore-dups',
        '-P', cli[:outdir],
        '-t', cli[:dataset_type],
        '-i', stage,
        '-R', cli[:regexp]
      ] + cli.files
    ) unless cli.files.empty?
  end

  def summarize(which = %w[cds assembly essential_genes ssu])
    return if cli[:prepare_and_exit]

    which.each do |r|
      cli.say "Summary: #{r}"
      call_cli(
        [
          'summary',
          '-P', cli[:outdir], '-r', r, '--tab', '--ref', '--active',
          '-o', File.join(cli[:outdir], "#{r}.tsv")
        ]
      )
    end
    call_cli(['browse', '-P', cli[:outdir]])
  end

  def cleanup
    return if cli[:prepare_and_exit]
    return unless cli[:clean]

    cli.say 'Cleaning up intermediate files'
    %w[data daemon metadata miga.project.json].each do |f|
      FileUtils.rm_rf(File.expand_path(f, cli[:outdir]))
    end
  end

  def call_cli(cmd)
    cmd << '-v' if cli[:verbose]
    MiGA::MiGA.DEBUG "Cli::Action::Wf.call_cli #{cmd}"
    MiGA::Cli.new(cmd.map(&:to_s)).launch(true)
  end

  def run_daemon
    return if cli[:prepare_and_exit]

    cmd  = ['daemon', 'run', '-P', cli[:outdir], '--shutdown-when-done']
    cmd += ['--json', cli[:daemon_json]] if cli[:daemon_json]
    cmd += ['--max-jobs', cli[:jobs]] if cli[:jobs]
    cmd += ['--ppn', cli[:threads]] if cli[:threads]
    cmd += ['--ppn-project', cli[:threads_project]] if cli[:threads_project]
    cmd += ['--debug', MiGA::MiGA.debug_trace? ? '2' : '1'] if MiGA::MiGA.debug?
    cwd = Dir.pwd
    call_cli(cmd)
    Dir.chdir(cwd)
  end

  def transfer_metadata(obj, md)
    # Clear old metadata
    obj.metadata.each do |k, v|
      obj.metadata[k] = nil if k.to_s =~ /^run_/ || obj.option?(k)
    end
    # Transfer and save
    md.each { |k, v| obj.metadata[k] = v }
    obj.save
  end

  private

  ##
  # Add option --type or --project-type to +opt+
  def opt_object_type(opt, obj, multi)
    conf =
      case obj
      when :dataset
        ['type', 'datasets', :dataset_type, MiGA::Dataset]
      when :project
        ['project-type', 'project', :project_type, MiGA::Project]
      else
        raise "Unrecognized object type: #{obj}"
      end

    options =
      conf[3].KNOWN_TYPES.map do |k, v|
        "~ #{k}: #{v[:description]}" unless !multi && v[:multi]
      end.compact

    opt.on(
      "--#{conf[0]} STRING",
      "Type of #{conf[1]}. By default: #{cli[conf[2]]}",
      'Recognized types:',
      *options
    ) { |v| cli[conf[2]] = v.downcase.to_sym }
  end
end
