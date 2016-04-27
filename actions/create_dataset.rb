#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, ref:true}
OptionParser.new do |opt|
   opt.banner = <<BAN
Creates an empty dataset in a pre-existing MiGA project.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt_object(opt, o)
   opt.on("-t", "--type STRING",
      "Type of dataset. Recognized types include:",
      *MiGA::Dataset.KNOWN_TYPES.map{ |k,v| "~ #{k}: #{v[:description]}"}
      ){ |v| o[:type]=v.to_sym }
   opt.on("-q", "--query",
      "If set, the dataset is registered as a query, not a reference dataset."
      ){ |v| o[:ref]=!v }
   opt.on("-d", "--description STRING",
      "Description of the dataset."){ |v| o[:description]=v }
   opt.on("-u", "--user STRING",
      "Owner of the dataset."){ |v| o[:user]=v }
   opt.on("-c", "--comments STRING",
      "Comments on the dataset."){ |v| o[:comments]=v }
   opt_common(opt, o)
end.parse!


### MAIN
raise "-P is mandatory." if o[:project].nil?
raise "-D is mandatory." if o[:dataset].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Creating dataset." unless o[:q]
md = {}
[:type, :description, :user, :comments].each{ |k| md[k]=o[k] unless o[k].nil? }
d = MiGA::Dataset.new(p, o[:dataset], o[:ref], md)
p.add_dataset(o[:dataset])
res = d.first_preprocessing(true)
$stderr.puts "- #{res}" unless o[:q]

$stderr.puts "Done." unless o[:q]

