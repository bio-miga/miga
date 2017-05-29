#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require "miga/tax_dist"

o = {q:true, details:false, json:true}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset])
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P", dataset:"-D")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Loading dataset." unless o[:q]
ds = p.dataset(o[:dataset])

$stderr.puts "Finding closest relative." unless o[:q]
cr = ds.closest_relatives(1)

unless cr.empty?
  $stderr.puts "Querying probability distributions." unless o[:q]
  cr = cr[0]
  tax = p.dataset(cr[0]).metadata[:tax]
  tax ||= {}
  r = MiGA::TaxDist.aai_pvalues(cr[1], :intax).map do |k,v|
    sig = ""
    [0.5,0.1,0.05,0.01].each{ |i| sig << "*" if v<i }
    [MiGA::Taxonomy.LONG_RANKS[k], (tax[k] || ""), v, sig]
  end
  puts "Taxonomic classification"
  puts MiGA::MiGA.tabulate(%w[Rank Taxonomy P-value Significance], r)
  puts "  Significance at p-value below:"
  puts "  *0.5, **0.1, ***0.05, ****0.01."
end

$stderr.puts "Done." unless o[:q]
