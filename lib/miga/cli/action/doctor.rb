# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'sqlite3'

class MiGA::Cli::Action::Doctor < MiGA::Cli::Action

  def parse_cli
    @@OPERATIONS.keys.each { |i| cli.defaults = { i => true } }
    cli.parse do |opt|
      operation_n = Hash[@@OPERATIONS.map { |k,v| [v[0], k] }]
      cli.opt_object(opt, [:project])
      opt.on(
        '--ignore TASK1,TASK2', Array,
        'Do not perform the task(s) listed. Available tasks are:',
        * @@OPERATIONS.values.map { |v| "~ #{v[0]}: #{v[1]}" }
      ) { |v| v.map { |i| cli[operation_n[i]] = false } }
      opt.on(
        '--only TASK',
        'Perform only the specified task (see --ignore)'
      ) do |v|
        op_k = @@OPERATIONS.find { |_, i| i[0] == v.downcase }.first
        @@OPERATIONS.keys.each { |i| cli[i] = false }
        cli[op_k] = true
      end
    end
  end

  def check_sqlite3_database(db_file, metric)
    SQLite3::Database.new(db_file) do |conn|
      conn.execute("select count(*) from #{metric}").first
    end
  rescue SQLite3::SQLException
    yield
  end

  def perform
    p = cli.load_project
    @@OPERATIONS.keys.each do |k|
      send("check_#{k}", cli) if cli[k]
    end
  end

  @@OPERATIONS = {
    db: ['databases', 'Check database files integrity'],
    dist: ['distances', 'Check distance summary tables'],
    files: ['files', 'Check for outdated files'],
    cds: ['cds', 'Check for gzipped genes and proteins'],
    ess: ['essential-genes', 'Check for unarchived essential genes'],
    mts: ['mytaxa-scan', 'Check for unarchived MyTaxa scan'],
    start: ['start', 'Check for lingering .start files'],
    tax: ['taxonomy', 'Check for taxonomy consistency (not yet implemented)']
  }
  class << self
    def OPERATIONS
      @@OPERATIONS
    end
  end

  def check_db(cli)
    cli.say 'Checking databases integrity'
    cli.load_project.each_dataset do |d|
      [:distances, :taxonomy].each do |r_key|
        r = d.result(r_key) or next
        {haai_db: :aai, aai_db: :aai, ani_db: :ani}.each do |db_key, metric|
          db_file = r.file_path(db_key) or next
          check_sqlite3_database(db_file, metric) do
            cli.say(
              "  > Removing #{db_key} #{r_key} table for #{d.name}")
            [db_file, r.path(:done), r.path].each do |f|
              File.unlink(f) if File.exist? f
            end # each |f|
          end # check_sqlite3_database
        end # each |db_key, metric|
      end # each |r_key|
    end # each |d|
  end

  def check_dist(cli)
    p = cli.load_project
    [:ani, :aai].each do |dist|
      res = p.result("#{dist}_distances")
      next if res.nil?
      cli.say "Checking #{dist} table for consistent datasets"
      notok, fix = check_dist_eval(cli, p, res)
      check_dist_fix(cli, p, fix)
      check_dist_recompute(cli, res, notok)
    end
  end

  def check_files(cli)
    cli.say 'Looking for outdated files in results'
    p = cli.load_project
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
          cli.say "  > Registering again #{d.name}:#{r_k}"
          d.add_result(r_k, true, force: true)
        end
      end
    end
  end

  def check_cds(cli)
    cli.say 'Looking for unzipped genes or proteins'
    cli.load_project.each_dataset do |d|
      res = d.result(:cds) or next
      changed = false
      [:genes, :proteins, :gff3, :gff2, :tab].each do |f|
        file = res.file_path(f) or next
        if file !~ /\.gz/
          cli.say "  > Gzipping #{d.name} #{f}"
          cmdo = `gzip -9 '#{file}'`.chomp
          warn(cmdo) unless cmdo.empty?
          changed = true
        end
      end
      d.add_result(:cds, true, force: true) if changed
    end
  end

  def check_ess(cli)
    cli.say 'Looking for unarchived essential genes'
    cli.load_project.each_dataset do |d|
      res = d.result(:essential_genes)
      next if res.nil?
      dir = res.file_path(:collection)
      if dir.nil?
        cli.say "  > Removing #{d.name}:essential_genes"
        res.remove!
        next
      end
      next if Dir["#{dir}/*.faa"].empty?
      cli.say "  > Fixing #{d.name}"
      cmdo = `cd '#{dir}' && tar -zcf proteins.tar.gz *.faa && rm *.faa`.chomp
      warn(cmdo) unless cmdo.empty?
    end
  end

  def check_mts(cli)
    cli.say 'Looking for unarchived MyTaxa Scan runs'
    cli.load_project.each_dataset do |d|
      res = d.result(:mytaxa_scan)
      next if res.nil?
      dir = res.file_path(:regions)
      fix = false
      unless dir.nil?
        if Dir.exist? dir
          cmdo = `cd '#{dir}/..' \
                && tar -zcf '#{d.name}.reg.tar.gz' '#{d.name}.reg' \
                && rm -r '#{d.name}.reg'`.chomp
          warn(cmdo) unless cmdo.empty?
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
        cli.say "  > Fixing #{d.name}"
        d.add_result(:mytaxa_scan, true, force: true)
      end
    end
  end

  def check_start(cli)
    cli.say 'Looking for legacy .start files lingering'
    cli.load_project.each_dataset do |d|
      d.each_result do |r_k, r|
        if File.exist? r.path(:start)
          cli.say "  > Registering again #{d.name}:#{r_k}"
          r.save
        end
      end
    end
  end

  def check_tax(cli)
    #cli.say 'o Checking for taxonomy/distances consistency'
    # TODO: Find 95%ANI clusters with entries from different species
  end

  private

  def check_dist_eval(cli, p, res)
    notok = {}
    fix = {}
    Zlib::GzipReader.open(res.file_path(:matrix)) do |fh|
      lineno = 0
      fh.each_line do |ln|
        next if (lineno += 1) == 1
        r = ln.split("\t")
        next unless [1, 2].map { |i| p.dataset(r[i]).nil? }.any?
        [1, 2].each do |i|
          if p.dataset(r[i]).nil?
            notok[r[i]] = true
          else
            fix[r[i]] = true
          end
        end
      end
    end
    [notok, fix]
  end

  def check_dist_fix(cli, p, fix)
    return if fix.empty?
    cli.say("- Fixing #{fix.size} datasets")
    fix.keys.each do |d_n|
      cli.say "  > Fixing #{d_n}."
      p.dataset(d_n).cleanup_distances!
    end
  end

  def check_dist_recompute(cli, p, notok)
    return if notok.empty?
    cli.say '- Unregistered datasets detected: '
    if notok.size <= 5
      notok.keys.each { |i| cli.say "  > #{i}" }
    else
      cli.say "  > #{notok.size}, including #{notok.keys.first}"
    end
    cli.say '- Removing tables, recompute'
    res.remove!
  end
end
