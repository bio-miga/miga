# @package MiGA
# @license Artistic-2.0

require 'miga/daemon'
require 'miga/common/with_daemon'

##
# Lair of MiGA Daemons handling job submissions
class MiGA::Lair < MiGA::MiGA
  include MiGA::Common::WithDaemon
  extend MiGA::Common::WithDaemonClass

  # Absolute path to the directory where the projects are located
  attr_reader :path

  # Options used to setup the chief daemon
  attr_accessor :options

  ##
  # Initialize an inactive daemon for the directory at +path+. See #daemon
  # to wake the chief daemon. Supported options include:
  # - json: json definition for all children daemons, by default: nil
  # - latency: time to wait between iterations in seconds, by default: 120
  # - wait_for: time to wait for a daemon to report being alive in seconds,
  #   by default: 30
  # - keep_inactive: boolean indicating if daemons should stay alive even when
  #   inactive (when all tasks are complete), by default: false
  # - name: A name for the chief daemon process, by default: basename of +path+
  # - trust_timestamp: boolean indicating if the +modified+ timestamp of the
  #   project is to be trusted to determine changes in the project,
  #   by default: true
  # - dry: Only report when daemons would be launched, but don't actually launch
  #   them
  def initialize(path, opts = {})
    @path = File.expand_path(path)
    @options = opts
    {
      json: nil,
      latency: 30,
      wait_for: 30,
      keep_inactive: false,
      trust_timestamp: true,
      name: File.basename(@path),
      dry: false
    }.each { |k, v| @options[k] = v if @options[k].nil? }
  end

  ##
  # Path to the lair's chief daemon's home
  alias daemon_home path

  ##
  # Name of the lair's chief daemon
  def daemon_name
    "MiGA:#{options[:name]}"
  end

  ##
  # First loop of the lair's chief daemon
  def daemon_first_loop
    say '-----------------------------------'
    say '%s launched' % daemon_name
    say '-----------------------------------'
    say 'Configuration options:'
    say options.to_s
  end

  ##
  # Run one loop step. Returns a Boolean indicating if the loop should continue.
  def daemon_loop
    check_directories
    return false if options[:dry]

    sleep(options[:latency])
    true
  end

  ##
  # Terminate all daemons in the lair (including the chief daemon)
  def terminate_daemons
    terminate_daemon(self)
    each_project do |project|
      terminate_daemon(MiGA::Daemon.new(project))
    end
  end

  ##
  # Send termination message to +daemon+, an object implementing
  # +MiGA::Common::WithDaemon+
  def terminate_daemon(daemon)
    say "Probing #{daemon.class} #{daemon.daemon_home}"
    if daemon.active?
      say 'Sending termination message'
      FileUtils.touch(daemon.terminate_file)
    end
  end

  ##
  # Perform block for each project in the +dir+ directory,
  # passing the absolute path of the project to the block.
  # Searches for MiGA projects recursively in all
  # subdirectories that are not MiGA projects.
  def each_project(dir = path)
    Dir.entries(dir).each do |f|
      next if %w[. ..].include?(f) # Ruby <= 2.3 doesn't have Dir.children

      f = File.join(dir, f)
      if MiGA::Project.exist? f
        project = MiGA::Project.load(f)
        raise "Cannot load project: #{f}" if project.nil?

        yield(project)
      elsif Dir.exist? f
        each_project(f) { |p| yield(p) }
      end
    end
  end

  ##
  # Perform block for each daemon, including the chief daemon
  # if +include_self+.
  def each_daemon(include_self = true)
    yield(self) if include_self
    each_project { |project| yield(MiGA::Daemon.new(project)) }
  end

  ##
  # Traverse directories checking MiGA projects
  def check_directories
    each_project do |project|
      d = MiGA::Daemon.new(project)
      next if d.active?

      l_alive = d.last_alive
      unless l_alive.nil?
        next if options[:trust_timestamp] && project.metadata.updated < l_alive
        next if l_alive > Time.now - options[:wait_for]
      end
      launch_daemon(project)
    end
  end

  ##
  # Launch daemon for the MiGA::Project +project+
  def launch_daemon(project)
    say "Launching daemon: #{project.path}"
    d = MiGA::Daemon.new(project, options[:json])
    d.runopts(:shutdown_when_done, true) unless options[:keep_inactive]
    unless options[:dry]
      d.start
      sleep(1) # <- to make sure the daemon started up (it takes about 0.1 secs)
    end
  end
end
