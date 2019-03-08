#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q: true}
opts = OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt])
  opt_common(opt, o)
end.parse!

##=> Main <=
opts.parse!
opt_require(o, project: '-P')

$stderr.puts 'Loading project.' unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

n = nil
if not o[:dataset].nil?
  $stderr.puts 'Loading dataset.' unless o[:q]
  d = p.dataset o[:dataset]
  raise "Impossible to load dataset: #{o[:dataset]}" if d.nil?
  n = d.next_preprocessing if d.is_active?
else
  n = p.next_distances(false)
  n ||= p.next_inclade(false)
end
n ||= '?'
puts n

