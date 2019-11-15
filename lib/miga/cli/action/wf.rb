# @package MiGA
# @license Artistic-2.0

##
# Helper module for workflows
module MiGA::Cli::Action::Wf
  def default_opts_for_wf
    cli.expect_files = true
    cli.defaults = {
      clean: false, regexp: MiGA::Cli.FILE_REGEXP,
      project_type: :genomes, dataset_type: :popgenome }
  end

  def opts_for_wf(opt, files_desc)
    opt.on(
      '-o', '--out_dir PATH',
      'Directory to be created with all output data'
    ) { |v| cli[:outdir] = v }
    opt.separator ''
    opt.separator "    FILES...: #{files_desc}"
    opt.separator ''
    opt.separator 'Workflow Control Options'
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
      "Type of datasets. By default: #{cli[:dataset_type]}",
      'Recognized types include:',
      *MiGA::Dataset.KNOWN_TYPES
        .map { |k, v| "~ #{k}: #{v[:description]}" unless v[:multi] }
    ) { |v| cli[:dataset_type] = v.downcase.to_sym }
    opt.on(
      '--daemon PATH',
      'Use custom daemon configuration in JSON format',
      'By default: ~/.miga_daemon.json'
    ) { |v| cli[:daemon_json] = v }
    opt.on(
      '-j', '--jobs INT',
      'Number of parallel jobs to execute',
      'By default controlled by the daemon configuration (maxjobs)'
    ) { |v| cli[:jobs] = v.to_i }
    opt.on(
      '-t', '--threads INT',
      'Number of CPUs to use per job',
      'By default controlled by the daemon configuration (ppn)'
    ) { |v| cli[:threads] = v.to_i }
  end

  def create_project(stage)
    cli.ensure_par(
      outdir: '-o',
      project_type: '--project-type',
      dataset_type: '--dataset-type')
    # Create empty project
    call_cli(['new', '-P', cli[:outdir], '-t', cli[:project_type]])
    # Add datasets
    call_cli([
      'add',
      '-P', cli[:outdir],
      '-t', cli[:dataset_type],
      '-i', stage,
      '-R', cli[:regexp]
    ] + cli.files)
    p = MiGA::Project.load(cli[:outdir])
    raise "Impossible to create project: #{cli[:outdir]}" if p.nil?
    p
  end

  def call_cli(cmd)
    cmd << '-v' if cli[:verbose]
    MiGA::Cli.new(cmd.map(&:to_s)).launch
  end

  def run_daemon
    cmd  = ['daemon', 'run', '-P', cli[:outdir], '--shutdown-when-done']
    cmd += ['--json', cli[:daemon_json]] unless cli[:daemon_json].nil?
    cmd += ['--max-jobs', cli[:jobs]] unless cli[:jobs].nil?
    cmd += ['--ppn', cli[:threads]] unless cli[:threads].nil?
    cwd = Dir.pwd
    call_cli cmd
    Dir.chdir(cwd)
  end

end
