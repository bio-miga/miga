# @package MiGA
# @license Artistic-2.0

class MiGA::Cli::Action::Doctor < MiGA::Cli::Action
  require 'miga/cli/action/doctor/base'
  require 'miga/cli/action/doctor/distances'
  require 'miga/cli/action/doctor/operations'
  include MiGA::Cli::Action::Doctor::Base
  include MiGA::Cli::Action::Doctor::Distances
  include MiGA::Cli::Action::Doctor::Operations

  def parse_cli
    cli.defaults = { threads: 1 }
    cli.defaults = Hash[@@OPERATIONS.keys.map { |i| [i, true] }]
    cli.parse do |opt|
      operation_n = Hash[@@OPERATIONS.map { |k, v| [v[0], k] }]
      cli.opt_object(opt, [:project])
      opt.on(
        '--ignore TASK1,TASK2', Array,
        'Do not perform the task(s) listed. Available tasks are:',
        * @@OPERATIONS.values.map { |v| "~ #{v[0]}: #{v[1]}" }
      ) { |v| v.map { |i| cli[operation_n[i]] = false } }
      opt.on(
        '--only TASK',
        'Perform only the specified task (see --ignore)'
      ) do |v|
        op_k = @@OPERATIONS.find { |_, i| i[0] == v.downcase }.first
        @@OPERATIONS.each_key { |i| cli[i] = false }
        cli[op_k] = true
      end
      opt.on(
        '-t', '--threads INT', Integer,
        "Concurrent threads to use. By default: #{cli[:threads]}"
      ) { |v| cli[:threads] = v }
    end
  end

  def perform
    p = cli.load_project
    @@OPERATIONS.keys.each do |k|
      send("check_#{k}", cli) if cli[k]
    end
  end

  @@OPERATIONS = {
    status: ['status', 'Update metadata status of all datasets'],
    db: ['databases', 'Check integrity of database files'],
    bidir: ['bidirectional', 'Check distances are bidirectional'],
    dist: ['distances', 'Check distance summary tables'],
    files: ['files', 'Check for outdated files'],
    cds: ['cds', 'Check for gzipped genes and proteins'],
    ess: ['essential-genes', 'Check for outdated essential genes'],
    mts: ['mytaxa-scan', 'Check for unarchived MyTaxa scan'],
    start: ['start', 'Check for lingering .start files'],
    tax: ['taxonomy', 'Check for taxonomy consistency (not yet implemented)']
  }

  class << self
    ##
    # All supported operations
    def OPERATIONS
      @@OPERATIONS
    end
  end
end
