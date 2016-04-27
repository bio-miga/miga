#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, info:false, processing:false}
OptionParser.new do |opt|
  opt.banner = <<BAN
Lists all registered datasets in an MiGA project.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
  opt_object(opt, o, [:project, :dataset_opt])
  opt.on("--[no-]ref",
    "If set, lists only reference (or only non-reference) datasets."
    ){ |v| o[:ref]=v }
  opt.on("--[no-]multi",
    "If set, lists only multi-species (or only single-species) datasets."
    ){ |v| o[:multi]=v }
  opt.on("-i", "--info",
    "Print additional information on each dataset."){ |v| o[:info]=v }
  opt.on("-p", "--processing",
    "Print information on processing advance."){ |v| o[:processing]=v }
  opt.on("-t", "--taxonomy RANK:TAXON",
    "Filter by taxonomy."){ |v| o[:taxonomy]=MiGA::Taxonomy.new v }
  opt.on("-m", "--metadata STRING",
    "Print name and metadata field only. If set, ignores -i."
    ){ |v| o[:datum]=v }
  opt_common(opt, o)
end.parse!


### MAIN
raise "-P is mandatory." if o[:project].nil?

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
ds.select!{|d| d.is_ref? == o[:ref] } unless o[:ref].nil?
ds.select! do |d|
  (not d.metadata[:type].nil?) and
    (MiGA::Dataset.KNOWN_TYPES[d.metadata[:type]][:multi] == o[:multi])
end unless o[:multi].nil?
ds.select! do |d|
  (not d.metadata[:tax].nil?) and d.metadata[:tax].is_in?(o[:taxonomy])
end unless o[:taxonomy].nil?
if not o[:datum].nil?
  ds.each{|d| puts "#{d.name}\t#{d.metadata[ o[:datum] ] || "?"}"}
elsif o[:info]
  puts MiGA::MiGA.tabulate(MiGA::Dataset.INFO_FIELDS, ds.map{ |d| d.info })
elsif o[:processing]
  comp = ["undef","done","queued"]
  puts MiGA::MiGA.tabulate([:name] + MiGA::Dataset.PREPROCESSING_TASKS,
    ds.map{ |d| [d.name] + d.profile_advance.map{ |i| comp[i] } })
else
  ds.each{|d| puts d.name}
end

$stderr.puts "Done." unless o[:q]
