#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true}
opts = OptionParser.new do |opt|
   opt.banner = <<BAN
Registers a result.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt_object(opt, o, [:project, :dataset_opt])
   opt.on("-r", "--result STRING",
      "(Mandatory) Name of the result to add.",
      "Recognized names for dataset-specific results include:",
      *MiGA::Dataset.RESULT_DIRS.keys.map{|n| " ~ #{n}"},
      "Recognized names for project-wide results include:",
      *MiGA::Project.RESULT_DIRS.keys.map{|n| " ~ #{n}"}){ |v| o[:name]=v }
   opt_common(opt, o)
end.parse!


### MAIN
opts.parse!
raise "-P is mandatory." if o[:project].nil?
raise "-r is mandatory." if o[:name].nil?

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

