# @package MiGA
# @license Artistic-2.0

require 'miga/project'
require 'miga/common/with_daemon'
require 'miga/daemon/base'

##
# MiGA Daemons handling job submissions.
class MiGA::Daemon < MiGA::MiGA

  include MiGA::Daemon::Base
  include MiGA::Common::WithDaemon
  extend MiGA::Common::WithDaemonClass

  class << self
    ##
    # Daemon's home inside the MiGA::Project +project+ or a String with the
    # full path to the project's 'daemon' folder
    def daemon_home(project)
      return project if project.is_a? String
      File.join(project.path, 'daemon')
    end
  end

  # MiGA::Project in which the daemon is running
  attr_reader :project

  # Options used to setup the daemon
  attr_reader :options

  # Array of jobs next to be executed
  attr_reader :jobs_to_run

  # Array of jobs currently running
  attr_reader :jobs_running

  ##
  # Initialize an unactive daemon for the MiGA::Project +project+. See #daemon
  # to wake the daemon. If passed, +json+ must be the path to a daemon
  # definition in json format. Otherwise, the project-stored daemon definition
  # is used. In either case, missing variables are used as defined in
  # ~/.miga_daemon.json.
  def initialize(project, json = nil)
    @project = project
    @runopts = {}
    json ||= File.join(project.path, 'daemon/daemon.json')
    default_json = File.expand_path('.miga_daemon.json', ENV['MIGA_HOME'])
    MiGA::Json.parse(
      json, default: File.exist?(default_json) ? default_json : nil
    ).each { |k,v| runopts(k, v) }
    update_format_0
    @jobs_to_run = []
    @jobs_running = []
  end

  ##
  # Path to the daemon home
  def daemon_home
    self.class.daemon_home(project)
  end

  ##
  # Name of the daemon
  def daemon_name
    "MiGA:#{project.name}"
  end

  ##
  # Run only in the first loop
  def daemon_first_loop
    say '-----------------------------------'
    say 'MiGA:%s launched' % project.name
    say '-----------------------------------'
    load_status
    say 'Configuration options:'
    say @runopts.to_s
  end

  ##
  # Run one loop step. Returns a Boolean indicating if the loop should continue
  def daemon_loop
    l_say(3, 'Daemon loop start')
    reload_project
    check_datasets
    check_project
    if shutdown_when_done? and jobs_running.size + jobs_to_run.size == 0
      say 'Nothing else to do, shutting down.'
      return false
    end
    flush!
    purge! if loop_i > 0 && loop_i % 12 == 0
    save_status
    sleep(latency)
    l_say(3, 'Daemon loop end')
    true
  end

  ##
  # Send +msg+ to +say+ as long as +level+ is at most +verbosity+
  def l_say(level, *msg)
    say(*msg) if verbosity >= level
  end

  ##
  # Same as +l_say+ with +level = 1+
  def say(*msg)
    super(*msg) if 1 >= verbosity
  end

  ##
  # Reload the project's metadata
  def reload_project
    l_say(2, 'Reloading project')
    project.load
  end

  ##
  # Report status in a JSON file.
  def save_status
    l_say(2, 'Saving current status')
    MiGA::Json.generate(
      { jobs_running: @jobs_running, jobs_to_run: @jobs_to_run },
      File.join(daemon_home, 'status.json')
    )
  end

  ##
  # Load the status of a previous instance.
  def load_status
    f_path = File.join(daemon_home, 'status.json')
    return unless File.size? f_path
    say 'Loading previous status in daemon/status.json:'
    status = MiGA::Json.parse(f_path)
    status.keys.each do |i|
      status[i].map! do |j|
        j.tap do |k|
          unless k[:ds].nil? or k[:ds_name] == 'miga-project'
            k[:ds] = project.dataset(k[:ds_name])
          end
          k[:job] = k[:job].to_sym unless k[:job].nil?
        end
      end
    end
    @jobs_running = status[:jobs_running]
    @jobs_to_run  = status[:jobs_to_run]
    say "- jobs left running: #{@jobs_running.size}"
    purge!
    say "- jobs running: #{@jobs_running.size}"
    say "- jobs to run: #{@jobs_to_run.size}"
  end

  ##
  # Traverse datasets
  def check_datasets
    l_say(2, 'Checking datasets')
    project.each_dataset do |ds|
      to_run = ds.next_preprocessing(false)
      queue_job(:d, ds) unless to_run.nil?
    end
  end

  ##
  # Check if all reference datasets are pre-processed. If yes, check the
  # project-level tasks
  def check_project
    l_say(2, 'Checking project')
    return if project.dataset_names.empty?
    return unless project.done_preprocessing?(false)
    to_run = project.next_task(nil, false)
    queue_job(:p) unless to_run.nil?
  end

  ##
  # Add the task to the internal queue with symbol key +job+. If the task is
  # dataset-specific, +ds+ specifies the dataset. To submit jobs to the
  # scheduler (or to bash or ssh) see #flush!
  def queue_job(job, ds = nil)
    return nil unless get_job(job, ds).nil?
    ds_name = (ds.nil? ? 'miga-project' : ds.name)
    say 'Queueing %s:%s' % [ds_name, job]
    vars = {
      'PROJECT' => project.path,
      'RUNTYPE' => runopts(:type),
      'CORES'   => ppn,
      'MIGA'    => MiGA::MiGA.root_path
    }
    vars['DATASET'] = ds.name unless ds.nil?
    log_dir = File.expand_path("daemon/#{job}", project.path)
    Dir.mkdir(log_dir) unless Dir.exist? log_dir
    task_name = "#{project.metadata[:name][0..9]}:#{job}:#{ds_name}"
    to_run = { ds: ds, ds_name: ds_name, job: job, task_name: task_name }
    to_run[:cmd] = runopts(:cmd).miga_variables(
      script: MiGA::MiGA.script_path(job, miga:vars['MIGA'], project: project),
      vars: vars.map { |k, v|
        runopts(:var).miga_variables(key: k, value: v) }.join(runopts(:varsep)),
      cpus: ppn,
      log: File.expand_path("#{ds_name}.log", log_dir),
      task_name: task_name,
      miga: File.expand_path('bin/miga', MiGA::MiGA.root_path).shellescape
    )
    @jobs_to_run << to_run
  end

  ##
  # Get the taks with key symbol +job+ in dataset +ds+. For project-wide tasks
  # let +ds+ be nil.
  def get_job(job, ds = nil)
    (jobs_to_run + jobs_running).find do |j|
      if ds.nil?
        j[:ds].nil? and j[:job] == job
      else
        (! j[:ds].nil?) and j[:ds].name == ds.name and j[:job] == job
      end
    end
  end

  ##
  # Remove finished jobs from the internal queue and launch as many as
  # possible respecting #maxjobs or #nodelist (if set).
  def flush!
    # Check for finished jobs
    l_say(2, 'Checking for finished jobs')
    @jobs_running.select! do |job|
      ongoing = case job[:job].to_s
      when 'd'
        !job[:ds].nil? && !job[:ds].next_preprocessing(false).nil?
      when 'p'
        !project.next_task(nil, false).nil?
      else
        (job[:ds].nil? ? project : job[:ds]).add_result(job[:job], false).nil?
      end
      say "Completed pid:#{job[:pid]} for #{job[:task_name]}" unless ongoing
      ongoing
    end

    # Avoid single datasets hogging resources
    @jobs_to_run.rotate! rand(jobs_to_run.size)

    # Launch as many +jobs_to_run+ as possible
    while hostk = next_host
      break if jobs_to_run.empty?
      launch_job(@jobs_to_run.shift, hostk)
    end
  end

  ##
  # In SSH daemons, retrieve the host index of an available node, nil if none.
  # In any other daemons, returns true as long as #maxjobs is not reached
  def next_host
    return jobs_running.size < maxjobs if runopts(:type) != 'ssh'
    allk = (0 .. nodelist.size-1).to_a
    busyk = jobs_running.map { |k| k[:hostk] }
    (allk - busyk).first
  end

  ##
  # Remove dead jobs.
  def purge!
    say 'Probing running jobs'
    @jobs_running.select! do |job|
      `#{runopts(:alive).miga_variables(pid: job[:pid])}`.chomp.to_i == 1
    end
  end

  ##
  # Launch the job described by Hash +job+ to +hostk+-th host
  def launch_job(job, hostk = nil)
    # Execute job
    case runopts(:type)
    when 'ssh'
      # Remote job
      job[:hostk] = hostk
      job[:cmd] = job[:cmd].miga_variables(host: nodelist[hostk])
      job[:pid] = spawn job[:cmd]
      Process.detach job[:pid] unless [nil, '', 0].include?(job[:pid])
    when 'bash'
      # Local job
      job[:pid] = spawn job[:cmd]
      Process.detach job[:pid] unless [nil, '', 0].include?(job[:pid])
    else
      # Schedule cluster job (qsub, msub, slurm)
      job[:pid] = `#{job[:cmd]}`.chomp
    end

    # Check if registered
    if [nil, '', 0].include? job[:pid]
      job[:pid] = nil
      @jobs_to_run << job
      say "Unsuccessful #{job[:task_name]}, rescheduling"
    else
      @jobs_running << job
      say "Spawned pid:#{job[:pid]}#{
            " to #{job[:hostk]}:#{nodelist[job[:hostk]]}" if job[:hostk]
          } for #{job[:task_name]}"
    end
  end

  ##
  # Update from daemon JSON format 0 to the latest version
  def update_format_0
    {
      cmd: %w[script vars cpus log task_name],
      var: %w[key value],
      alive: %w[pid],
      kill: %w[pid]
    }.each do |k,v|
      runopts(
        k, runopts(k).gsub(/%(\d+\$)?d/, '%\\1s') % v.map{ |i| "{{#{i}}}" }
      ) if !runopts(k).nil? && runopts(k) =~ /%(\d+\$)?[ds]/
    end
    runopts(:format_version, 1)
  end
end
