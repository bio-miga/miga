#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require "miga/tax_index"

o = {q:true, format: :json}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on("-i", "--index PATH",
    "(Mandatory) File to create with the index."){ |v| o[:index]=v }
  opt.on("-f", "--format STRING",
    "Format of the index file. By default: #{o[:format]}. Supported: " +
    "json, tab."){ |v| o[:format]=v.to_sym }
  opt_filter_datasets(opt, o)
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P", index:"-i")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Loading datasets." unless o[:q]
ds = p.datasets
ds.select!{|d| not d.metadata[:tax].nil? }
ds = filter_datasets!(ds, o)

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
