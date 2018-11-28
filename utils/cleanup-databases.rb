#!/usr/bin/env ruby

require 'thread'
require 'miga'

ARGV[1] or abort "Usage: #{$0} path/to/project threads"

$stderr.puts "Cleaning databases..."
ds_list = MiGA::Project.load(ARGV[0]).datasets.
  select(&:is_ref?).select(&:is_active?)

thr = ARGV[1].to_i

(0 .. thr-1).each do |t|
  fork do
    k = -1
    ds_list.each do |i|
      k = (k+1) % thr
      next unless k == t
      i.cleanup_distances!
    end
  end
end
Process.waitall

