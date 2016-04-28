#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, add:false, ref:true}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_type])
  opt.on("-a", "--add",
    "Register the datasets found. By default, only lists them (dry run)."
    ){ |v| o[:add]=v }
  opt.on("-q", "--query",
    "If set, all datasets are registered as query datasets."
    ){ |v| o[:ref]=!v }
  opt.on("-u", "--user STRING", "Owner of the dataset."){ |v| o[:user]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Finding datasets." unless o[:q]
ud = p.unregistered_datasets
ud.each do |dn|
  puts dn
  if o[:add]
    md = {}
    [:type, :user].each{ |k| md[k]=o[k] unless o[k].nil? }
    d = MiGA::Dataset.new(p, dn, o[:ref], md)
    p.add_dataset(dn)
    res = d.first_preprocessing
    puts "- #{res}" unless o[:q]
  end
end

$stderr.puts "Done." unless o[:q]
