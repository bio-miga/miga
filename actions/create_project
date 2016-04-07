#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, update:false}
OptionParser.new do |opt|
   opt.banner = <<BAN
Creates an empty MiGA project.

Usage: #{$0} #{File.basename(__FILE__)} [options]
BAN
   opt.separator ""
   opt.on("-P", "--project PATH",
      "(Mandatory) Path to the project to create."){ |v| o[:project]=v }
   opt.on("-t", "--type STRING",
      "Type of dataset. Recognized types include:", 
      *MiGA::Project.KNOWN_TYPES.map{ |k,v| "~ #{k}: #{v[:description]}"}
      ){ |v| o[:type]=v.to_sym }
   opt.on("-n", "--name STRING",
      "Name of the project."){ |v| o[:name]=v }
   opt.on("-d", "--description STRING",
      "Description of the project."){ |v| o[:description]=v }
   opt.on("-u", "--user STRING", "Owner of the project."){ |v| o[:user]=v }
   opt.on("-c", "--comments STRING",
      "Comments on the project."){ |v| o[:comments]=v }
   opt.on("--update",
      "Updates the project if it already exists."){ o[:update]=true }
   opt.on("-v", "--verbose",
      "Print additional information to STDERR."){ o[:q]=false }
   opt.on("-d", "--debug INT", "Print debugging information to STDERR.") do |v|
      v.to_i>1 ? MiGA::MiGA.DEBUG_TRACE_ON : MiGA::MiGA.DEBUG_ON
   end
   opt.on("-h", "--help", "Display this screen.") do
      puts opt
      exit
   end
   opt.separator ""
end.parse!


### MAIN
raise "-P is mandatory." if o[:project].nil?

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

