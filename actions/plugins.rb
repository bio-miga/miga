#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, update:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on("--install PATH",
    "Installs the specified plugin in the project."){ |v| o[:install]=v }
  opt.on("--uninstall PATH",
    "Uninstalls the specified plugin from the project."){ |v| o[:uninstall]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P")

p = MiGA::Project.new(o[:project], true)
p.install_plugin(o[:install]) unless o[:install].nil?
p.uninstall_plugin(o[:uninstall]) unless o[:uninstall].nil?
p.plugins.each { |i| puts i }

$stderr.puts "Done." unless o[:q]
