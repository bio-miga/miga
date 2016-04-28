#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, details:false, json:true}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt])
  opt.on("-i", "--info",
    "If set, it prints additional details for each file."
    ){ |v| o[:details]=v }
  opt.on("--[no-]json",
    "If set to no, excludes json files containing results metadata."
    ){ |v| o[:json]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

if o[:dataset].nil?
  results = p.results
else
  $stderr.puts "Loading dataset." unless o[:q]
  ds = p.dataset(o[:dataset])
  raise "Impossible to load dataset: #{o[:dataset]}" if ds.nil?
  results = ds.results
end

$stderr.puts "Listing files." unless o[:q]
results.each do |result|
  puts "#{ "#{result.path}\t\t" if o[:details] }#{result.path}" if o[:json]
  result.each_file do |k,f|
    puts "#{ "#{result.path}\t#{k}\t" if o[:details] }#{result.dir}/#{f}"
  end
end

$stderr.puts "Done." unless o[:q]
