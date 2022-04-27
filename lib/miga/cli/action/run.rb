# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Run < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { try_load: false, thr: 1, env: false, check_first: false }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt, :result_opt])
      opt.on(
        '-t', '--threads INT', Integer,
        "Threads to use in the local run (by default: #{cli[:thr]})"
      ) { |v| cli[:thr] = v }
      opt.on(
        '-R', '--remote STR',
        'Description of remote SSH node to launch the job, as "user@hostname"',
        'By default, the job is executed locally'
      ) { |v| cli[:remote] = v }
      opt.on(
        '-l', '--log PATH',
        'Path to the output log file to be created. If not set, STDOUT'
      ) { |v| cli[:log] = v }
      opt.on(
        '-e', '--environment',
        'Load PROJECT, DATASET, and CORES from the environment'
      ) { |v| cli[:env] = v }
      opt.on(
        '--check-first',
        'Check if the result exists, and run only if it does not'
      ) { |v| cli[:check_first] = v }
    end
  end

  def perform
    # Load environment variables if requested (typically by the daemon)
    if cli[:env]
      cli[:project] ||= ENV['PROJECT']
      cli[:dataset] ||= ENV['DATASET']
      cli[:thr] = ENV['CORES'].to_i unless ENV['CORES'].nil?
      cli[:result] = File.basename(cli[:result].to_s, '.bash').to_sym
    end
    %i[project dataset result].each do |i|
      cli[i] = nil if cli[i].nil? || cli[i].empty?
    end

    # Unset dataset if the requested result is for projects
    if (MiGA::Project.RESULT_DIRS.keys + [:p]).include? cli[:result]
      cli[:dataset] = nil
    end

    # Use virtual result if not explicitly passed
    cli[:result] ||= cli[:dataset] ? :d : :p

    # Load project
    p = cli.load_project

    # Check if result already exists
    if cli[:check_first]
      obj = cli[:dataset] ? p.dataset(cli[:dataset]) : p
      if obj.result(cli[:result])
        cli.say('Result already exists')
        return
      end
    end

    # Prepare command
    miga = MiGA.root_path
    opts = {}
    cmd = [
      "PROJECT=#{p.path.shellescape}",
      "RUNTYPE=#{cli[:remote] ? 'ssh' : 'bash'}",
      "MIGA=#{miga.shellescape}",
      "CORES=#{cli[:thr]}"
    ]
    obj = cli.load_project_or_dataset
    klass = obj.class
    virtual_task = %i[p d maintenance].include?(cli[:result])
    cmd << "DATASET=#{obj.name.shellescape}" if obj.is_a? MiGA::Dataset
    if klass.RESULT_DIRS[cli[:result]].nil? and not virtual_task
      raise "Unsupported #{klass.to_s.sub(/.*::/, '')} result: #{cli[:result]}."
    end

    cmd << MiGA.script_path(cli[:result], miga: miga, project: p).shellescape
    if cli[:remote]
      cmd = [
        'ssh', '-t', '-t',
        cli[:remote].shellescape,
        cmd.join(' ').shellescape
      ]
    end

    if cli[:log]
      opts[:stdout] = cli[:log]
      opts[:err2out] = true
    end

    # Launch
    # note that all elements were carefully escaped in advace, so this has to be
    # passed as String to avoid double-escaping or unintentionally escaping
    # characters such as `=` and `>`
    MiGA::MiGA.run_cmd(cmd.join(' '), opts)
  end
end
