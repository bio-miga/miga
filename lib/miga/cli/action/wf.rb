# @package MiGA
# @license Artistic-2.0

##
# Helper module for workflows
module MiGA::Cli::Action::Wf
  def opts_for_wf(opt, files_desc)
    opt.separator ''
    opt.separator "    FILES...: #{files_desc}"
    opt.separator ''
    opt.separator 'General Options'
    opt.on(
      '--daemon PATH',
      'Use custom daemon configuration in JSON format',
      'By default: ~/.miga_daemon.json'
    ) { |v| cli[:daemon_json] = v }
    opt.on(
      '-t', '--threads INT',
      'Number of parallel jobs to execute',
      'By default controlled by the daemon configuration'
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
    cmd = ['daemon', 'run', '-P', cli[:outdir], '--shutdown-when-done']
    cmd += ['--json', cli[:daemon_json]] unless cli[:daemon_json].nil?
    cmd += ['--max-jobs', cli[:threads]] unless cli[:threads].nil?
    cwd = Dir.pwd
    call_cli cmd
    Dir.chdir(cwd)
  end

end
