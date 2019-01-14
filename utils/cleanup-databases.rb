#!/usr/bin/env ruby

require 'thread'
require 'miga'

ARGV[1] or abort "Usage: #{$0} path/to/project threads"

$stderr.puts "Cleaning databases..."
p = MiGA::Project.load(ARGV[0])
ds_names = p.dataset_names
thr = ARGV[1].to_i

(0 .. thr-1).each do |t|
  fork do
    k = -1
    ds_names.each do |i|
      k = (k+1) % thr
      next unless k == t
      d = p.dataset(i)
      next unless d.is_ref? and d.is_active?
      i.cleanup_distances!
    end
  end
end
Process.waitall

