#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, info:false, processing:false, tabular:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on("-p", "--processing",
    "Print information on processing advance."){ |v| o[:processing]=v }
  opt.on("-m", "--metadata STRING",
    "Print name and metadata field only."
    ){ |v| o[:datum]=v }
  opt.on("--tab",
    "Returns a tab-delimited table."){ |v| o[:tabular] = v }
  opt_common(opt, o)
end.parse!


##=> Main <=
opt_require(o, project:"-P")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

if not o[:datum].nil?
  v = p.metadata[ o[:datum] ]
  puts v.nil? ? "?" : v
elsif o[:processing]
  keys = MiGA::Project.DISTANCE_TASKS + MiGA::Project.INCLADE_TASKS
  puts MiGA::MiGA.tabulate([:task, :status], keys.map do |k|
    [k, p.add_result(k, false).nil? ? "queued" : "done"]
  end, o[:tabular])
else
  puts MiGA::MiGA.tabulate([:key, :value], p.metadata.data.keys.map do |k|
    v = p.metadata[k]
    [k, k==:datasets ? v.size : v]
  end, o[:tabular])
end

$stderr.puts "Done." unless o[:q]
