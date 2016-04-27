#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, remove:false}
OptionParser.new do |opt|
   opt.banner = <<BAN
Removes a dataset from an MiGA project.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt_object(opt, o)
   opt.on("-r", "--remove",
      "Also remove all associated files.",
      "By default, only unlinks from metadata."){ o[:remove]=true }
   opt_common(opt, o)
end.parse!


### MAIN
raise "-P is mandatory." if o[:project].nil?
raise "-D is mandatory." if o[:dataset].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Unlinking dataset." unless o[:q]
raise "Dataset doesn't exist, aborting." unless
   MiGA::Dataset.exist?(p, o[:dataset])
d = p.unlink_dataset(o[:dataset])
d.remove! if o[:remove]

$stderr.puts "Done." unless o[:q]

