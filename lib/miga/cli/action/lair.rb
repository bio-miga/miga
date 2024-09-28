# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'miga/lair'

class MiGA::Cli::Action::Lair < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { daemon_opts: [] }
    cli.expect_operation = true
    cli.parse do |opt|
      opt.separator 'Available operations:'
      {
        start: 'Start an instance of the application',
        stop: 'Start an instance of the application',
        run: 'Start the application and stay on top',
        status: 'Show status (PID) of application instances',
        list: 'List all daemons and their status',
        running: 'List running daemons only',
        terminate: 'Terminate all daemons in the lair and exit'
      }.each { |k, v| opt.separator sprintf('    %*s%s', -33, k, v) }
      opt.separator ''

      opt.separator 'MiGA options:'
      opt.on(
        '-p', '--path PATH',
        '(Mandatory) Path to the directory where the MiGA projects are located'
      ) { |v| cli[:path] = v }
      opt.on(
        '--exclude NAME1,NAME2,NAME3', Array,
        'Exclude these projects (identified by name) from the lair'
      ) { |v| cli[:exclude] = v }
      opt.on(
        '--json PATH',
        'Path to a custom daemon definition in json format'
      ) { |v| cli[:json] = v }
      opt.on(
        '--latency INT', Integer,
        'Time to wait between iterations in seconds, by default: 120'
      ) { |v| cli[:latency] = v }
      opt.on(
        '--wait-for INT', Integer,
        'Time to wait for a daemon to report being alive in seconds',
        'by default: 30'
      ) { |v| cli[:wait_for] = v }
      opt.on(
        '--keep-inactive',
        'If set, daemons are kept alive even when inactive;',
        'i.e., when all tasks are complete'
      ) { |v| cli[:keep_inactive] = v }
      opt.on(
        '--no-trust-timestamp',
        'Check all results instead of trusting project timestamps'
      ) { |v| cli[:trust_timestamp] = v }
      opt.on(
        '--name STRING',
        'A name for the chief daemon process'
      ) { |v| cli[:name] = v }
      opt.on(
        '--dry',
        'Report when daemons would be launched, but don\'t actually launch them'
      ) { |v| cli[:dry] = v }
      cli.opt_common(opt)

      opt.separator 'Daemon options:'
      opt.on(
        '-t', '--ontop',
        'Stay on top (does not daemonize)'
      ) { cli[:daemon_opts] << '-t' }
      opt.on(
        '-f', '--force',
        'Force operation'
      ) { cli[:daemon_opts] << '-f' }
      opt.on(
        '-n', '--no_wait',
        'Do not wait for processes to stop'
      ) { cli[:daemon_opts] << '-n' }
      opt.on(
        '--shush',
        'Silence the daemon'
      ) { cli[:daemon_opts] << '--shush' }
      opt.separator ''
    end
  end

  def perform
    cli.ensure_par(path: '-p')
    k_opts = %i[
      json latency wait_for keep_inactive trust_timestamp name dry exclude
    ]
    opts = Hash[k_opts.map { |k| [k, cli[k]] }]
    lair = MiGA::Lair.new(cli[:path], opts)

    case cli.operation.to_sym
    when :terminate
      lair.terminate_daemons
    when :list, :running
      o = []
      lair.each_daemon do |d|
        o << [d.daemon_name, d.class, d.daemon_home, d.active?, d.last_alive]
      end
      if cli.operation.to_sym == :running
        o.select! { |i| i[3] }.map! { |i| i[0..-3] }
        cli.table(%w[name class path], o)
      else
        cli.table(%w[name class path active last_alive], o)
      end
    else
      lair.daemon(cli.operation, cli[:daemon_opts])
    end
  end
end
