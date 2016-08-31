#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true}
opts = OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt, :result])
  opt_common(opt, o)
end.parse!

##=> Main <=
opts.parse!
opt_require(o, project:"-P", name:"-r")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Registering result." unless o[:q]
if o[:dataset].nil?
  r = p.add_result o[:name].to_sym
else
  d = p.dataset(o[:dataset])
  r = d.add_result o[:name].to_sym
end

raise "Cannot add result, incomplete expected files." if r.nil?

$stderr.puts "Done." unless o[:q]
