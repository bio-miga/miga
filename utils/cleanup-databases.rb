#!/usr/bin/env ruby

require 'miga'

ARGV[1] or abort "Usage: #{$0} path/to/project threads"

p = MiGA::Project.load(ARGV[0])
thr = [ARGV[1].to_i, 1].max

p.say 'Cleaning Databases'
ds = p.dataset_ref_active

MiGA::Parallel.distribute(ds, thr) do |d, k, t|
  p.advance('Dataset:', k, ds.size) if t == 0
  d.cleanup_distances!
end
p.advance('Dataset:', ds.size, ds.size)
p.say
