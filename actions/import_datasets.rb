#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, info:false, force:false, method: :hardlink }
OptionParser.new do |opt|
   opt.banner = <<BAN
Link datasets (including results) from one project to another.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt_object(opt, o, [:project, :dataset_opt])
   opt.on("-Q", "--project-target PATH",
      "(Mandatory) Path to the project where to link the dataset."
      ){ |v| o[:project2]=v }
   opt.on("-f", "--force",
      "Forces linking, even if dataset's preprocessing is incomplete."
      ){ |v| o[:force]=v }
   opt.on("-s", "--symlink",
      "Creates symlinks instead of the default hard links."
      ){ o[:method] = :symlink }
   opt.on("-c", "--copy",
      "Creates copies instead of the default hard links."){ o[:method] = :copy }
   opt_filter_datasets(opt, o)
   opt_common(opt, o)
end.parse!


### MAIN
raise "-P is mandatory." if o[:project].nil?
raise "-Q is mandatory." if o[:project2].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?
q = MiGA::Project.load(o[:project2])
raise "Impossible to load project: #{o[:project2]}" if q.nil?

$stderr.puts "Listing dataset." unless o[:q]
if o[:dataset].nil?
   ds = p.datasets
else
   ds = [p.dataset(o[:dataset])]
end
ds = filter_datasets!(ds, o)
ds.each do |d|
   next unless o[:force] or d.done_preprocessing?
   puts d.name
   q.import_dataset(d, o[:method])
end

$stderr.puts "Done." unless o[:q]

