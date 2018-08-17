#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, units:false, tabular:false}
opts = OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt, :result_dataset])
  opt.on("--tab STRING",
    "Returns a tab-delimited table."){ |v| o[:tabular] = v }
  opt.on("--key STRING",
    "Returns only the value of the requested key."){ |v| o[:key] = v }
  opt.on("--with-units",
    "Includes units in each cell."){ |v| o[:units] = v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opts.parse!
opt_require(o, project:"-P", name:"-r")

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

$stderr.puts "Loading results." unless o[:q]
stats = ds.map do |d|
  r = d.add_result(o[:name].to_sym, false)
  s = r.nil? ? {} : r[:stats]
  s.tap{ |i| i[:dataset] = d.name }
end
keys = o[:key].nil? ? stats.map(&:keys).flatten.uniq :
      [:dataset, o[:key].downcase.miga_name.to_sym]
keys.delete :dataset
keys.unshift :dataset

table = o[:units] ?
      stats.map{ |s| keys.map{ |k|
            s[k].is_a?(Array) ? s[k].map(&:to_s).join('') : s[k] } } :
      stats.map{ |s| keys.map{ |k| s[k].is_a?(Array) ? s[k].first : s[k] } }
puts MiGA::MiGA.tabulate(keys, table, o[:tabular])

$stderr.puts "Done." unless o[:q]

