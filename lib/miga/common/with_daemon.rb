
require 'daemons'
require 'miga/common/with_daemon_class'

##
# Helper module with specific functions to handle objects that have daemons.
# The class including it must +extend MiGA::Common::WithDaemonClass+ and define:
# - +#daemon_home+ Path to the daemon's home
# - +#daemon_name+ Name of the daemon
# - +#daemon_loop+ One loop of the daemon to be repeatedly called
# - +#daemon_first_loop+ To be executed before the first call to +#daemon_loop+
module MiGA::Common::WithDaemon
  # Process ID of the forked process declaring the daemon alive
  attr :declare_alive_pid

  # Loop counter
  attr :loop_i

  def pid_file
    File.join(daemon_home, "#{daemon_name}.pid")
  end

  def output_file
    File.join(daemon_home, "#{daemon_name}.output")
  end
  
  def terminate_file
    File.join(daemon_home, 'terminate-daemon')
  end

  def alive_file
    self.class.alive_file(daemon_home)
  end

  def terminated_file
    self.class.terminated_file(daemon_home)
  end

  ##
  # When was the daemon last seen active?
  def last_alive
    self.class.last_alive(daemon_home)
  end

  ##
  # Is the daemon active?
  def active?
    return false unless File.exist? alive_file
    (last_alive || Time.new(0)) > Time.now - 60
  end

  ##
  # Tell the world that you're alive.
  def declare_alive
    if active?
      raise "Trying to declare alive an active daemon, if you think this is a" \
        " mistake please remove #{alive_file} or try again in 1 minute"
    end
    @declare_alive_pid = fork { declare_alive_loop }
    sleep(1) # <- to wait for the process check
  end

  ##
  # Loop checking if the process with PID +pid+ is still alive.
  # By default, the parent process.
  # Do not use directly, use +declare_alive+ instead.
  # Returns a symbol indicating the reason to stop:
  # - +:no_home+ Daemon's home does not exist
  # - +:no_process_alive+ Process is not currently running
  # - +:termination_file+ Found termination file
  def declare_alive_loop(pid = Process.ppid)
    i = -1
    loop do
      i += 1
      return :no_home unless Dir.exist? daemon_home
      return :no_process_alive unless process_alive? pid
      write_alive_file if i % 30 == 0
      return :termination_file if termination_file? pid
      sleep(1)
    end
  end

  def write_alive_file
    File.open(alive_file, 'w') { |fh| fh.print Time.now.to_s }
  end

  ##
  # Check if the process with PID +pid+ is still alive,
  # call +terminate+ otherwise.
  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH, Errno::EPERM, Errno::ENOENT
    terminate
    false
  end

  ##
  # Check if a termination file exists and terminate process with PID +pid+
  # if it does. Do not kill any process if +pid+ is +nil+
  def termination_file?(pid)
    return false unless File.exist? terminate_file
    say 'Found termination file, terminating'
    File.unlink(terminate_file)
    terminate
    Process.kill(9, pid) unless pid.nil?
    true
  end

  ##
  # Returns Hash containing the default options for the daemon.
  def default_options
    {
      dir_mode: :normal, dir: daemon_home, multiple: false, log_output: true,
      stop_proc: :terminate
    }
  end

  ##
  # Launches the +task+ with options +opts+ (as command-line arguments) and
  # returns the process ID as an Integer. If +wait+ it waits for the process to
  # complete, immediately returns otherwise.
  # Supported tasks: start, run, stop, status.
  def daemon(task, opts = [], wait = true)
    MiGA::MiGA.DEBUG "#{self.class}#daemon #{task} #{opts}"
    task = task.to_sym
    raise "Unsupported task: #{task}" unless respond_to? task
    return send(task, opts, wait) unless %i[start run].include? task

    # start & run:
    options = default_options
    opts.unshift(task.to_s)
    options[:ARGV] = opts
    # This additional degree of separation below was introduced so the Daemons
    # package doesn't kill the parent process in workflows.
    pid = fork { launch_daemon_proc(options) }
    Process.wait(pid) if wait
    pid
  end

  ##
  # Stops the daemon with +opts+
  def stop(opts = [], wait = true)
    if active?
      say 'Sending termination message'
      FileUtils.touch(terminate_file)
      sleep(0.5) while active? if wait
      File.unlink(pid_file) if File.exist?(pid_file)
    else
      say 'No running instances'
    end
  end

  ##
  # Returns the status of the daemon with +opts+
  def status(opts = [], wait = true)
    if active?
      say "Running with pid #{File.read(pid_file)}"
    else
      say 'Not running'
    end
  end

  ##
  # Pass daemon options to +Daemons+. Do not use directly, use +daemon+ instead.
  def launch_daemon_proc(options)
    Daemons.run_proc("#{daemon_name}", options) { while in_loop; end }
  end

  ##
  # Initializes the daemon with +opts+
  def start(opts = [], wait = true)
    daemon(:start, opts, wait)
  end

  ##
  # Initializes the daemon on top with +opts+
  def run(opts = [], wait = true)
    daemon(:run, opts, wait)
  end

  ##
  # One loop, returns a boolean indicating if the execution should continue
  def in_loop
    if loop_i.nil?
      declare_alive
      daemon_first_loop
      @loop_i = -1
    end
    @loop_i += 1
    daemon_loop
  end

  ##
  # Declares a daemon termination. Do not use, directly, use #stop instead.
  def terminate
    unless declare_alive_pid.nil?
      Process.kill(9, declare_alive_pid)
      @declare_alive_pid = nil
    end
    File.rename(alive_file, terminated_file) if File.exist? alive_file
  end
end
