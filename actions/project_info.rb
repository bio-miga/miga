#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, info:false, processing:false}
OptionParser.new do |opt|
  opt.banner = <<BAN
Displays information about a MiGA project.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
  opt.separator ""
  opt.on("-P", "--project PATH",
    "(Mandatory) Path to the project to read."){ |v| o[:project]=v }
  opt.on("-p", "--processing",
    "Print information on processing advance."){ |v| o[:processing]=v }
  opt.on("-m", "--metadata STRING",
    "Print name and metadata field only. If set, ignores -i."
    ){ |v| o[:datum]=v }
  opt.on("-v", "--verbose",
    "Print additional information to STDERR."){ o[:q]=false }
  opt.on("-d", "--debug INT", "Print debugging information to STDERR.") do |v|
    v.to_i>1 ? MiGA::MiGA.DEBUG_TRACE_ON : MiGA::MiGA.DEBUG_ON
  end
  opt.on("-h", "--help", "Display this screen.") do
    puts opt
    exit
  end
  opt.separator ""
end.parse!


### MAIN
raise "-P is mandatory." if o[:project].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

if not o[:datum].nil?
  puts (p.metadata[ o[:datum] ] || "?")
elsif o[:processing]
  comp = ["undef","done","queued"]
  keys = MiGA::Project.DISTANCE_TASKS + MiGA::Project.INCLADE_TASKS
  puts MiGA::MiGA.tabulate([:task, :status], keys.map do |k|
    [k, p.add_result(k, false).nil? ? "queued" : "done"]
  end)
else
  puts MiGA::MiGA.tabulate([:key, :value], p.metadata.data.keys.map do |k|
    v = p.metadata[k]
    [k, k==:datasets ? v.size : v]
  end)
end

$stderr.puts "Done." unless o[:q]
