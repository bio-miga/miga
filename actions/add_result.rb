#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, force:false}
opts = OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt, :result])
  opt.on("-f", "--force",
    "Forces re-indexing of the result even if it's already registered."
    ){ |v| o[:force]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opts.parse!
opt_require(o, project:"-P", name:"-r")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Registering result." unless o[:q]
obj = o[:dataset].nil? ? p : p.dataset(o[:dataset])
r = obj.add_result(o[:name].to_sym, true, force: o[:force])

raise "Cannot add result, incomplete expected files." if r.nil?

$stderr.puts "Done." unless o[:q]
