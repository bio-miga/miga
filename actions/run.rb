#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require 'shellwords'

o = {q: true, try_load: false, thr: 1}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt, :result])
  opt.on('-t', '--threads INT',
    "Threads to use in the local run (by default: #{o[:thr]})."
    ){ |v| o[:thr] = v.to_i }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project: '-P', name: '-r')

$stderr.puts 'Loading project.' unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

miga = MiGA::MiGA.root_path
cmd = ["PROJECT=#{p.path.shellescape}", 'RUNTYPE=bash',
  "MIGA=#{miga.shellescape}", "CORES=#{o[:thr]}"]
if o[:dataset].nil?
  type = MiGA::Project
else
  d = p.dataset(o[:dataset])
  raise 'Cannot load dataset.' if d.nil?
  cmd << "DATASET=#{d.name.shellescape}"
  type = MiGA::Dataset
end
raise "Unsupported #{type.to_s.gsub(/.*::/,"")} result: #{o[:name]}." if
  type.RESULT_DIRS[o[:name].to_sym].nil? and not %w[d p].include? o[:name]
cmd << MiGA::MiGA.script_path(o[:name], miga: miga, project: p).shellescape
pid = spawn cmd.join(' ')
Process.wait pid

$stderr.puts 'Done.' unless o[:q]
