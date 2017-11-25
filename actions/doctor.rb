#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, v:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on("-v", "--verbose",
    "Print additional information on advance."){ |v| o[:v]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P")

$stderr.puts "Loading project" unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

[:ani, :aai].each do |dist|
  r = p.result("#{dist}_distances")
  next if r.nil?
  $stderr.puts "o Checking #{dist} table for consistent datasets" unless o[:q]
  ok = true
  fix = {}
  Zlib::GzipReader.open(r.file_path(:matrix)) do |fh|
    fh.each_line do |ln|
      next if $.==1
      r = ln.split("\t")
      if p.dataset(r[1]).nil? or p.dataset(r[2]).nil?
        fix[r[2]] = true unless p.dataset(r[2]).nil?
        fix[r[1]] = true unless p.dataset(r[1]).nil?
        ok = false
      end
    end
  end
  
  $stderr.puts "  - Fixing #{fix.size} datasets" unless fix.empty? or o[:q]
  fix.keys.each do |d_n|
    $stderr.puts "    > Fixing #{d_n}." if o[:v]
    p.dataset(d_n).cleanup_distances!
  end
  
  unless ok
    $stderr.puts "  - Removing tables, recompute" unless o[:q]
    r.remove!
  end
end

$stderr.puts "o Looking for outdated files in results" unless o[:q]
p.each_dataset do |d|
  d.each_result do |r_k, r|
    ok = true
    r.each_file do |_f_sym, _f_rel, f_abs|
      unless File.exist? f_abs
        ok = false
        break
      end
    end
    unless ok
      $stderr.puts "  - Registering again #{d.name}:#{r_k}" if o[:v]
      d.add_result(r_k, true, force:true)
    end
  end
end

#$stderr.puts "o Looking for unarchived essential genes." unless o[:q]
#p.each_dataset do |d|
#  TODO: Check unarchived protein files
#end

#$stderr.puts "o Checking for taxonomy/distances consistency" unless o[:q]
# TODO: Find 95%ANI clusters with entries from different species

$stderr.puts "Done" unless o[:q]

