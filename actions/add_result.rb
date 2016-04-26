#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true}
opts = OptionParser.new do |opt|
   opt.banner = <<BAN
Registers a result.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt.separator ""
   opt.on("-P", "--project PATH",
      "(Mandatory) Path to the project to use."){ |v| o[:project]=v }
   opt.on("-D", "--dataset PATH",
      "(Mandatory if the result is dataset-specific) ID of the dataset to use."
      ){ |v| o[:dataset]=v }
   opt.on("-r", "--result STRING",
      "(Mandatory) Name of the result to add.",
      "Recognized names for dataset-specific results include:",
      *MiGA::Dataset.RESULT_DIRS.keys.map{|n| " ~ #{n}"},
      "Recognized names for project-wide results include:",
      *MiGA::Project.RESULT_DIRS.keys.map{|n| " ~ #{n}"}){ |v| o[:name]=v }
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

