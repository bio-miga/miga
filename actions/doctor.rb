#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require "sqlite3"

tasks = {
  db: ['databases', 'Check database files integrity'],
  dist: ['distances', 'Check distance summary tables.'],
  files: ['files', 'Check for outdated files.'],
  ess: ['essential-genes', 'Check for unarchived essential genes'],
  mts: ['mytaxa-scan', 'Check for unarchived MyTaxa scan'],
  start: ['start', 'Check for lingering .start files'],
  tax: ['taxonomy', 'Check for taxonomy consistency (not implemented)']
}
o = {q: true, ld: false}
tasks.keys.each{ |i| o[i] = true }
tasks_n = Hash[tasks.map{ |k,v| [v[0], k] }]

OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on('-l', '--list-datasets',
    'List all fixed datasets on advance.'){ |v| o[:ld]=v }
  opt.on('--ignore TASK1,TASK2', Array,
    'Do not perform the task(s) listed. Available tasks are:',
    * tasks.values.map{ |v| "#{v[0]}: #{v[1]}" }
    ){ |v| v.map{ |i| o[tasks_n[i]] = false } }
  opt.on('--only TASK',
    'Perform only the specified task (see --ignore).'
    ){ |v| tasks.keys.each{ |i| o[i] = false }; o[v] = true }
end.parse!

##=> Main <=
opt_require(o, project: '-P')

$stderr.puts 'Loading project' unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

def check_sqlite3_database(db_file, metric)
  begin
    SQLite3::Database.new(db_file) do |conn|
      conn.execute("select count(*) from #{metric}").first
    end
  rescue SQLite3::SQLException
    yield
  end
end

if o[:db]
  $stderr.puts 'o Checking databases integrity' unless o[:q]
  p.each_dataset do |d|
    [:distances, :taxonomy].each do |r_key|
      r = d.result(r_key) or next
      {haai_db: :aai, aai_db: :aai, ani_db: :ani}.each do |db_key, metric|
        db_file = r.file_path(db_key) or next
        check_sqlite3_database(db_file, metric) do
          $stderr.puts(
            "    > Removing #{db_key} #{r_key} table for #{d.name}.") if o[:ld]
          [db_file, r.path(:done), r.path].each do |f|
            File.unlink f if File.exist? f
          end # each |f|
        end # check_sqlite3_database
      end # each |db_key, metric|
    end # each |r_key|
  end # each |d|
end

[:ani, :aai].each do |dist|
  res = p.result("#{dist}_distances")
  next if res.nil?
  $stderr.puts "o Checking #{dist} table for consistent datasets" unless o[:q]
  notok = {}
  fix = {}
  Zlib::GzipReader.open(res.file_path(:matrix)) do |fh|
    lineno = 0
    fh.each_line do |ln|
      next if (lineno+=1)==1
      r = ln.split("\t")
      if [1,2].map{ |i| p.dataset(r[i]).nil? }.any?
        [1,2].each do |i|
          if p.dataset(r[i]).nil?
            notok[r[i]] = true
          else
            fix[r[i]] = true
          end
        end
      end
    end
  end
  
  $stderr.puts "  - Fixing #{fix.size} datasets" unless fix.empty? or o[:q]
  fix.keys.each do |d_n|
    $stderr.puts "    > Fixing #{d_n}." if o[:ld]
    p.dataset(d_n).cleanup_distances!
  end
  
  unless notok.empty?
    unless o[:q]
      $stderr.puts '  - Unregistered datasets detected: '
      if notok.size < 3
        $stderr.puts "    - #{notok.keys.join(', ')}"
      else
        $stderr.puts "    - #{notok.size}, including #{notok.keys.first}"
      end
      $stderr.puts '  - Removing tables, recompute'
    end
    res.remove!
  end
end if o[:dist]

if o[:files]
  $stderr.puts 'o Looking for outdated files in results' unless o[:q]
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
        d.add_result(r_k, true, force: true)
      end
    end
  end
end

if o[:ess]
  $stderr.puts 'o Looking for unarchived essential genes.' unless o[:q]
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
  $stderr.puts 'o Looking for unarchived MyTaxa Scan runs.' unless o[:q]
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
        FileUtils.rm(file) if File.exist? file
        fix = true
      end
    end
    if fix
      $stderr.puts "    > Fixing #{d.name}." if o[:ld]
      d.add_result(:mytaxa_scan, true, force: true)
    end
  end
end

if o[:start]
  $stderr.puts 'o Looking for legacy .start files lingering.' unless o[:q]
  p.each_dataset do |d|
    d.each_result do |r_k, r|
      if File.exist? r.path(:start)
        $stderr.puts "    > Registering again #{d.name}:#{r_k}" if o[:ld]
        r.save
      end
    end
  end
end

if o[:tax]
  #$stderr.puts "o Checking for taxonomy/distances consistency" unless o[:q]
  # TODO: Find 95%ANI clusters with entries from different species
end

$stderr.puts 'Done' unless o[:q]

