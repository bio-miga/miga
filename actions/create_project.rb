#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, update:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :project_type_req])
  opt.on("-n", "--name STRING",
    "Name of the project."){ |v| o[:name]=v }
  opt.on("-d", "--description STRING",
    "Description of the project."){ |v| o[:description]=v }
  opt.on("-u", "--user STRING", "Owner of the project."){ |v| o[:user]=v }
  opt.on("-c", "--comments STRING",
    "Comments on the project."){ |v| o[:comments]=v }
  opt.on("--update",
    "Updates the project if it already exists."){ o[:update]=true }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P", type:"-t")

unless File.exist? "#{ENV["HOME"]}/.miga_rc" and
      File.exist? "#{ENV["HOME"]}/.miga_daemon.json"
  puts "You must initialize MiGA before creating the first project.\n" +
    "Do you want to initialize MiGA now? (yes / no)"
  `'#{File.dirname(__FILE__)}/../scripts/init.bash'` if
    $stdin.gets.chomp == 'yes'
end

$stderr.puts "Creating project." unless o[:q]
raise "Project already exists, aborting." unless
  o[:update] or not MiGA::Project.exist? o[:project]
p = MiGA::Project.new(o[:project], o[:update])
# The following check is redundant with MiGA::Project#create,
# but allows upgrading projects from (very) early code versions
o[:name] = File.basename(p.path) if
  o[:update] and o[:name].nil?
[:name, :description, :user, :comments, :type].each do |k|
  p.metadata[k] = o[k] unless o[k].nil?
end
p.save

$stderr.puts "Done." unless o[:q]
