# @package MiGA
# @license Artistic-2.0

require 'daemons'
require 'miga/daemon'

##
# Lair of MiGA Daemons handling job submissions
class MiGA::Lair < MiGA::MiGA
  ##
  # When was the last time the chief daemon in this lair was seen active?
  # Returns Time
  def self.last_alive(path)
    f = File.expand_path('.lair-alive', path)
    return nil unless File.exist? f
    Time.parse(File.read(f))
  end

  # Absolute path to the directory where the projects are located
  attr_reader :path

  # Options used to setup the chief daemon
  attr_accessor :options

  # Integer indicating the current iteration
  attr_reader :loop_i

  ##
  # Initialize an inactive daemon for the directory at +path+. See #daemon
  # to wake the chief daemon. Supported options include:
  # - json: json definition for all children daemons, by default: nil
  # - latency: time to wait between iterations in seconds, by default: 120
  # - wait_for: time to wait for a daemon to report being alive in seconds,
  #   by default: 900
  # - keep_inactive: boolean indicating if daemons should stay alive even when
  #   inactive (when all tasks are complete), by default: false
  # - name: A name for the chief daemon process, by default: basename of +path+
  def initialize(path, opts = {})
    @path = File.expand_path(path)
    @options = opts
    @loop_i = -1
    {
      json: nil,
      latency: 120,
      wait_for: 900,
      keep_inactive: false,
      name: File.basename(@path)
    }.each { |k, v| @options[k] = v if @options[k].nil? }
  end

  ##
  # When was the last time the chief daemon for was seen active here?
  # Returns Time.
  def last_alive
    MiGA::Lair.last_alive path
  end

  ##
  # Returns Hash containing the default options for the daemon.
  def default_options
    { dir_mode: :normal, dir: path, multiple: false, log_output: true }
  end

  ##
  # Launches the +task+ with options +opts+ (as command-line arguments) and
  # returns the process ID as an Integer. If +wait+ it waits for the process to
  # complete, immediately returns otherwise.
  # Supported tasks: start, stop, restart, status.
  def daemon(task, opts = [], wait = true)
    MiGA.DEBUG "Lair.daemon #{task} #{opts}"
    config = default_options
    opts.unshift(task.to_s)
    config[:ARGV] = opts
    # This additional degree of separation below was introduced so the Daemons
    # package doesn't kill the parent process in workflows.
    pid = fork do
      Daemons.run_proc("MiGA:#{options[:name]}", config) { while in_loop; end }
    end
    Process.wait(pid) if wait
    pid
  end

  ##
  # Tell the world that you're alive.
  def declare_alive
    File.open(File.join(path, '.lair-alive'), 'w') do |fh|
      fh.print Time.now.to_s
    end
  end

  ##
  # Perform block for each project in the +dir+ directory,
  # passing the absolute path of the project to the block.
  # Searches for MiGA projects recursively in all
  # subdirectories that are not MiGA projects.
  def each_project(dir = path)
    Dir.entries(dir) do |f|
      f = File.join(dir, f)
      if MiGA::Project.exists? f
        yield(f)
      elsif Dir.exists? f
        each_project(f) { |p| yield(p) }
      end
    end
  end

  ##
  # Traverse directories checking MiGA projects
  def check_directories
    each_project do |dir|
      alive = MiGA::Daemon.last_alive(dir)
      next if !alive.nil? && alive > Time.now - options[:wait_for]
      launch_daemon(dir)
    end
  end

  ##
  # Launch daemon for the project stored in +dir+
  def launch_daemon(dir)
    project = MiGA::Project.load(dir)
    raise "Cannot load project: #{dir}" if project.nil?
    d = MiGA::Daemon.new(project, options[:json])
    d.runopts(:shutdown_when_done, true) unless options[:keep_inactive]
    say "Launching daemon: #{dir}"
    d.daemon(:start, [], false)
  end

  ##
  # Run one loop step. Returns a Boolean indicating if the loop should continue.
  def in_loop
    declare_alive
    if loop_i == -1
      say '-----------------------------------'
      say 'MiGA:%s launched' % options[:name]
      say '-----------------------------------'
      say 'Configuration options:'
      say options.to_s
      @loop_i = 0
    end
    @loop_i += 1
    check_directories
    sleep(options[:latency])
    true
  end

  ##
  # Terminates a chief daemon
  def terminate
    say 'Terminating chief daemon...'
    f = File.expand_path('.lair-alive', project.path)
    File.unlink(f) if File.exist? f
  end
end
