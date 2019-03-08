#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q: true}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt])
  opt.on('-m', '--metadata STRING',
    'Metadata as key-value pairs separated by = and delimited by comma.',
    'Values are saved as strings except for booleans (true / false) or nil.'
    ){ |v| o[:metadata] = v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project: '-P')

$stderr.puts 'Loading project.' unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

obj = p
if o[:dataset]
  $stderr.puts 'Loading dataset.' unless o[:q]
  obj = p.dataset(o[:dataset])
  raise 'Dataset does not exist.' if obj.nil?
end
obj = add_metadata(o, obj)
obj.save

$stderr.puts 'Done.' unless o[:q]
