#!/usr/bin/env ruby

require 'thread'
require 'miga'

ARGV[1] or abort "Usage: #{$0} path/to/project threads"

p = MiGA::Project.load(ARGV[0])
dsn = p.dataset_names
thr = ARGV[1].to_i

m = MiGA::MiGA.new
m.say 'Cleaning Databases'

(0..thr - 1).each do |t|
  fork do
    dsn.each_with_index do |i, idx|
      m.advance('Dataset:', idx + 1, dsn.size) if t == 0
      next unless (idx % thr) == t

      d = p.dataset(i)
      next unless d.ref? && d.active?

      d.cleanup_distances!
    end
  end
end
Process.waitall
m.advance('Dataset:', dsn.size, dsn.size)
m.say
