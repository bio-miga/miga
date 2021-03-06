#!/usr/bin/env ruby

$:.push File.expand_path('../../lib', __FILE__)
require 'miga'

proj_path = ARGV.shift or raise "Usage: #{$0} path/to/project"

# Load MiGA object
p = MiGA::Project.load(proj_path) or
  raise "Cannot load project: #{proj_path}"
pr = p.result(:clade_finding) or
  raise 'Unavailable result: clade_finding'
if (pf = pr.file_path(:clades_gsp)).nil?
  pf = pr.file_path(:clades_ani95) or
    raise 'Unavailable result files: clades_gsp and clades_ani95'
end

# Read ANIspp
ani_spp = []
File.open(pf, 'r') do |fh|
  fh.each_line do |ln|
    next if $. == 1 and ln.chomp == 'G' # <- Legacy check

    ani_spp << ln.chomp.split(',')
  end
end

# Find the best candidate
ani_spp.each_with_index do |datasets, i|
  best = nil
  datasets.each do |ds_name|
    d = p.dataset(ds_name) or next
    dr = d.result(:essential_genes) or next
    q = dr[:stats][:quality] or next
    if best.nil? or q > best[:q]
      best = { d: d, q: q }
    end
  end
  raise "Unavailable statistics for any of:\n#{datasets}\n" if best.nil?

  puts "ANIsp_#{i + 1}\t#{best[:d].name}"
end
