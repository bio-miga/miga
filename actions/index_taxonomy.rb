#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require "miga/tax_index"

o = {q:true, format: :json}
OptionParser.new do |opt|
   opt.banner = <<BAN
Creates a taxonomy-indexed list of the datasets.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt_object(opt, o, [:project])
   opt.on("-i", "--index PATH",
      "(Mandatory) File to create with the index."){ |v| o[:index]=v }
   opt.on("-f", "--format STRING",
      "Format of the index file. By default: #{o[:format]}. Supported: " +
      "json, tab."){ |v| o[:format]=v.to_sym }
   opt.on("--[no-]multi",
      "If set, lists only multi-species (or only single-species) datasets."
      ){ |v| o[:multi]=v }
   opt_common(opt, o)
end.parse!

### MAIN
raise "-P is mandatory." if o[:project].nil?
raise "-i is mandatory." if o[:index].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Loading datasets." unless o[:q]
ds = p.datasets
ds.select!{|d| not d.metadata[:tax].nil? }
ds.select! do |d|
   (not d.metadata[:type].nil?) and
      (MiGA::Dataset.KNOWN_TYPES[d.metadata[:type]][:multi] == o[:multi])
end unless o[:multi].nil?

$stderr.puts "Indexing taxonomy." unless o[:q]
tax_index = MiGA::TaxIndex.new
ds.each { |d| tax_index << d }

$stderr.puts "Saving index." unless o[:q]
fh = File.open(o[:index], "w")
if o[:format]==:json
   fh.print tax_index.to_json
elsif o[:format]==:tab
   fh.print tax_index.to_tab
end
fh.close

$stderr.puts "Done." unless o[:q]

