#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, ld:false,
  dist: true, files: true, ess: true, mts: true, tax: true}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on("-l", "--list-datasets",
    "List all fixed datasets on advance."){ |v| o[:ld]=v }
  opt.on("--ignore-distances",
    "Do not check distance tables."){ |v| o[:dist]=!v }
  opt.on("--ignore-files",
    "Do not check for outdated files."){ |v| o[:files]=!v }
  opt.on("--ignore-essential-genes",
    "Do not check unarchived essential genes."){ |v| o[:ess]=!v }
  opt.on("--ignore-mytaxa-scan",
    "Do not check unarchived MyTaxa scan."){ |v| o[:mts]=!v }
  opt.on("--ignore-taxonomy",
    "Do not check taxonomy consistency."){ |v| o[:tax]=!v }
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
end if o[:dist]

if o[:files]
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
        $stderr.puts "    > Registering again #{d.name}:#{r_k}" if o[:ld]
        d.add_result(r_k, true, force:true)
      end
    end
  end
end

if o[:ess]
  $stderr.puts "o Looking for unarchived essential genes." unless o[:q]
  p.each_dataset do |d|
    res = d.result(:essential_genes)
    next if res.nil?
    dir = res.file_path(:collection)
    if dir.nil?
      $stderr.puts "    > Removing #{d.name}:essential_genes" if o[:ld]
      res.remove!
      next
    end
    unless Dir["#{dir}/*.faa"].empty?
      $stderr.puts "    > Fixing #{d.name}." if o[:ld]
      cmdo = `cd '#{dir}' && tar -zcf proteins.tar.gz *.faa && rm *.faa`.chomp
      warn cmdo unless cmdo.empty?
    end
  end
end

if o[:mts]
  $stderr.puts "o Looking for unarchived MyTaxa Scan runs." unless o[:q]
  p.each_dataset do |d|
    res = d.result(:mytaxa_scan)
    next if res.nil?
    dir = res.file_path(:regions)
    fix = false
    unless dir.nil?
      if Dir.exist? dir
        cmdo = `cd '#{dir}/..' \
              && tar -zcf '#{d.name}.reg.tar.gz' '#{d.name}.reg' \
              && rm -r '#{d.name}.reg'`.chomp
        warn cmdo unless cmdo.empty?
      end
      fix = true
    end
    %w[blast mytaxain wintax gene_ids region_ids].each do |ext|
      file = res.file_path(ext.to_sym)
      unless file.nil?
        FileUtils.rm(file)
        fix = true
      end
    end
    if fix
      $stderr.puts "    > Fixing #{d.name}." if o[:ld]
      d.add_result(:mytaxa_scan, true, force: true)
    end
  end
end

if o[:tax]
  #$stderr.puts "o Checking for taxonomy/distances consistency" unless o[:q]
  # TODO: Find 95%ANI clusters with entries from different species
end

$stderr.puts "Done" unless o[:q]

