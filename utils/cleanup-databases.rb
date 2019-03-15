#!/usr/bin/env ruby

require 'thread'
require 'miga'

ARGV[1] or abort "Usage: #{$0} path/to/project threads"

$stderr.puts 'Cleaning databases...'
p = MiGA::Project.load(ARGV[0])
ds_names = p.dataset_names
thr = ARGV[1].to_i

pc = [0] + (1 .. 100).map{ |i| ds_names.size * i / 100 }
$stderr.puts (('.'*9 + '|')*10) + ' 100%'

(0 .. thr-1).each do |t|
  fork do
    ds_names.each_with_index do |i, idx|
      while t == 0 and idx+1 > pc.first
        $stderr.print '#'
        pc.shift
      end
      next unless (idx % thr) == t
      d = p.dataset(i)
      next unless d.is_ref? and d.is_active?
      d.cleanup_distances!
    end
  end
end
Process.waitall
$stderr.puts ' Done'

