#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, ld:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on("-l", "--list-datasets",
    "List all fixed datasets on advance."){ |v| o[:ld]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P")

$stderr.puts "Loading project" unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

[:ani, :aai].each do |dist|
  res = p.result("#{dist}_distances")
  next if res.nil?
  $stderr.puts "o Checking #{dist} table for consistent datasets" unless o[:q]
  ok = true
  fix = {}
  Zlib::GzipReader.open(res.file_path(:matrix)) do |fh|
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
    $stderr.puts "    > Fixing #{d_n}." if o[:ld]
    p.dataset(d_n).cleanup_distances!
  end
  
  unless ok
    $stderr.puts "  - Removing tables, recompute" unless o[:q]
    res.remove!
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
      $stderr.puts "  - Registering again #{d.name}:#{r_k}" if o[:ld]
      d.add_result(r_k, true, force:true)
    end
  end
end

$stderr.puts "o Looking for unarchived essential genes." unless o[:q]
p.each_dataset do |d|
  res = d.result(:essential_genes)
  next if res.nil?
  dir = res.file_path(:collection)
  if dir.nil?
    $stderr.puts "    > Incomplete ess_genes for #{d.name}, removing" if o[:ld]
    res.remove!
    next
  end
  unless Dir["#{dir}/*.faa"].empty?
    $stderr.puts "    > Fixing #{d.name}." if o[:ld]
    cmdo = `cd '#{dir}' && tar -zcf proteins.tar.gz *.faa && rm *.faa`.chomp
    warn cmdo unless cmdo.empty?
  end
end

#$stderr.puts "o Checking for taxonomy/distances consistency" unless o[:q]
# TODO: Find 95%ANI clusters with entries from different species

$stderr.puts "Done" unless o[:q]

