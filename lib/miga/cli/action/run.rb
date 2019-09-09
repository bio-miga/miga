# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'shellwords'

class MiGA::Cli::Action::Run < MiGA::Cli::Action

  def parse_cli
    cli.defaults = {try_load: false, thr: 1}
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt, :result])
      opt.on(
        '-t', '--threads INT', Integer,
        "Threads to use in the local run (by default: #{cli[:thr]})."
        ){ |v| cli[:thr] = v }
    end
  end

  def perform
    virtual_task = false
    miga = MiGA.root_path
    p = cli.load_project
    cmd = ["PROJECT=#{p.path.shellescape}", 'RUNTYPE=bash',
      "MIGA=#{miga.shellescape}", "CORES=#{cli[:thr]}"]

    obj = cli.load_project_or_dataset
    klass = obj.class
    virtual_task = true if [:p, :d].include? cli[:result]
    cmd << "DATASET=#{obj.name.shellescape}" if obj.is_a? MiGA::Dataset

    if klass.RESULT_DIRS[cli[:result]].nil? and not virtual_task
      raise "Unsupported #{klass.to_s.gsub(/.*::/, '')} result: #{cli[:result]}."
    end
    cmd << MiGA.script_path(cli[:result], miga: miga, project: p).shellescape
    pid = spawn cmd.join(' ')
    Process.wait pid
  end
end
