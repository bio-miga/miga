#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, info:false, processing:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt])
  opt_filter_datasets(opt, o)
  opt.on("-i", "--info",
    "Print additional information on each dataset."){ |v| o[:info]=v }
  opt.on("-p", "--processing",
    "Print information on processing advance."){ |v| o[:processing]=v }
  opt.on("-m", "--metadata STRING",
    "Print name and metadata field only. If set, ignores -i."
    ){ |v| o[:datum]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Listing datasets." unless o[:q]
if o[:dataset].nil?
  ds = p.datasets
elsif MiGA::Dataset.exist? p, o[:dataset]
  ds = [p.dataset(o[:dataset])]
else
  ds = []
end
ds = filter_datasets!(ds, o)

if not o[:datum].nil?
  ds.each{|d| puts "#{d.name}\t#{d.metadata[ o[:datum] ] || "?"}"}
elsif o[:info]
  puts MiGA::MiGA.tabulate(MiGA::Dataset.INFO_FIELDS, ds.map{ |d| d.info })
elsif o[:processing]
  comp = ["-","done","queued"]
  puts MiGA::MiGA.tabulate([:name] + MiGA::Dataset.PREPROCESSING_TASKS,
    ds.map{ |d| [d.name] + d.profile_advance.map{ |i| comp[i] } })
else
  ds.each{|d| puts d.name}
end

$stderr.puts "Done." unless o[:q]
