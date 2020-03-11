# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'miga/daemon'

class MiGA::Cli::Action::Daemon < MiGA::Cli::Action

  def parse_cli
    cli.defaults = {daemon_opts: []}
    cli.expect_operation = true
    cli.parse do |opt|
      opt.separator 'Available operations:'
      { start:   'Start an instance of the application.',
        stop:    'Start an instance of the application.',
        restart: 'Stop all instances and restart them afterwards.',
        reload:  'Send a SIGHUP to all instances of the application.',
        run:     'Start the application and stay on top.',
        zap:     'Set the application to a stopped state.',
        status:  'Show status (PID) of application instances.'
      }.each { |k,v| opt.separator sprintf '    %*s%s', -33, k, v }
      opt.separator ''

      opt.separator 'MiGA options:'
      cli.opt_object(opt, [:project])
      opt.on(
        '--shutdown-when-done',
        'Exit the daemon when all processing is done',
        'Otherwise, it will stay idle awaiting for new data (default)'
      ) { |v| cli[:shutdown_when_done] = v }
      opt.on(
        '--latency INT',
        'Number of seconds the daemon will be sleeping'
      ) { |v| cli[:latency] = v.to_i }
      opt.on(
        '--max-jobs INT',
        'Maximum number of jobs to use simultaneously'
      ) { |v| cli[:maxjobs] = v.to_i }
      opt.on(
        '--node-list PATH',
        'Path to the list of execution hostnames'
      ) { |v| cli[:nodelist] = v }
      opt.on(
        '--ppn INT',
        'Maximum number of cores to use in a single job'
      ) { |v| cli[:ppn] = v.to_i }
      opt.on(
        '--json PATH',
        'Path to a custom daemon definition in json format'
      ) { |v| cli[:json] = v }
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
    p = cli.load_project
    d = MiGA::Daemon.new(p, cli[:json])
    dopts = %i[latency maxjobs nodelist ppn shutdown_when_done]
    dopts.each { |k| d.runopts(k, cli[k]) }
    d.daemon(cli.operation, cli[:daemon_opts])
  end
end
