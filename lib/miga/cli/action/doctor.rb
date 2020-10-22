# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action/doctor/base'

class MiGA::Cli::Action::Doctor < MiGA::Cli::Action
  include MiGA::Cli::Action::Doctor::Base

  def parse_cli
    cli.defaults = { threads: 1 }
    cli.defaults = Hash[@@OPERATIONS.keys.map { |i| [i, true] }]
    cli.parse do |opt|
      operation_n = Hash[@@OPERATIONS.map { |k, v| [v[0], k] }]
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
        @@OPERATIONS.each_key { |i| cli[i] = false }
        cli[op_k] = true
      end
      opt.on(
        '-t', '--threads INT', Integer,
        "Concurrent threads to use. By default: #{cli[:threads]}"
      ) { |v| cli[:threads] = v }
    end
  end

  def perform
    p = cli.load_project
    @@OPERATIONS.keys.each do |k|
      send("check_#{k}", cli) if cli[k]
    end
  end

  @@OPERATIONS = {
    status: ['status', 'Update metadata status of all datasets'],
    db: ['databases', 'Check integrity of database files'],
    bidir: ['bidirectional', 'Check distances are bidirectional'],
    dist: ['distances', 'Check distance summary tables'],
    files: ['files', 'Check for outdated files'],
    cds: ['cds', 'Check for gzipped genes and proteins'],
    ess: ['essential-genes', 'Check for unarchived essential genes'],
    mts: ['mytaxa-scan', 'Check for unarchived MyTaxa scan'],
    start: ['start', 'Check for lingering .start files'],
    tax: ['taxonomy', 'Check for taxonomy consistency (not yet implemented)']
  }

  class << self
    ##
    # All supported operations
    def OPERATIONS
      @@OPERATIONS
    end
  end

  ##
  # Perform status operation with MiGA::Cli +cli+
  def check_status(cli)
    cli.say 'Updating metadata status'
    n, k = cli.load_project.dataset_names.size, 0
    cli.load_project.each_dataset do |d|
      cli.advance('Datasets:', k += 1, n, false)
      d.recalculate_status
    end
    cli.say
  end

  ##
  # Perform databases operation with MiGA::Cli +cli+
  def check_db(cli)
    cli.say 'Checking integrity of databases'
    n, k = cli.load_project.dataset_names.size, 0
    cli.load_project.each_dataset do |d|
      cli.advance('Datasets:', k += 1, n, false)
      each_database_file(d) do |db_file, metric, result|
        check_sqlite3_database(db_file, metric) do
          cli.say("  > Removing malformed database from #{d.name}:#{result}   ")
          File.unlink(db_file)
          r = d.result(result) or next
          [r.path(:done), r.path].each { |f| File.unlink(f) if File.exist?(f) }
        end
      end
    end
    cli.say
  end

  ##
  # Perform bidirectional operation with MiGA::Cli +cli+
  def check_bidir(cli)
    cli.say 'Checking that reference distances are bidirectional'
    ref_ds = cli.load_project.each_dataset.select(&:ref?)
    ref_names = ref_ds.map(&:name)
    n = ref_ds.size
    thrs = []
    (0 .. cli[:threads] - 1).map do |i|
      thrs << Thread.new do
        k = 0
        ref_ds.each do |d|
          k += 1
          cli.advance('Datasets:', k, n, false) if i == 0
          next unless k % cli[:threads] == i

          saved = saved_targets(d)
          next if saved.nil?

          (ref_names - saved).each do |k|
            save_bidirectional(cli.load_project.dataset(k), d)
          end
        end
      end
    end
    thrs.each(&:join)
    cli.say
  end

  ##
  # Perform distances operation with MiGA::Cli +cli+
  def check_dist(cli)
    p = cli.load_project
    %i[ani aai].each do |dist|
      res = p.result("#{dist}_distances")
      next if res.nil?

      cli.say "Checking #{dist} table for consistent datasets"
      notok, fix = check_dist_eval(cli, p, res)
      check_dist_fix(cli, p, fix)
      check_dist_recompute(cli, res, notok)
    end
  end

  ##
  # Perform files operation with MiGA::Cli +cli+
  def check_files(cli)
    cli.say 'Looking for outdated files in results'
    n, k = cli.load_project.dataset_names.size, 0
    cli.load_project.each_dataset do |d|
      cli.advance('Datasets:', k += 1, n, false)
      d.each_result do |r_k, r|
        ok = true
        r.each_file do |_f_sym, _f_rel, f_abs|
          unless File.exist? f_abs
            ok = false
            break
          end
        end
        unless ok
          cli.say "  > Registering again #{d.name}:#{r_k}   "
          d.add_result(r_k, true, force: true)
          sr = d.result(:stats) and sr.remove!
        end
      end
    end
    cli.say
  end

  ##
  # Perform cds operation with MiGA::Cli +cli+
  def check_cds(cli)
    cli.say 'Looking for unzipped genes or proteins'
    n, k = cli.load_project.dataset_names.size, 0
    cli.load_project.each_dataset do |d|
      cli.advance('Datasets:', k += 1, n, false)
      res = d.result(:cds) or next
      changed = false
      %i[genes proteins gff3 gff2 tab].each do |f|
        file = res.file_path(f) or next
        if file !~ /\.gz/
          cli.say "  > Gzipping #{d.name} #{f}   "
          cmdo = `gzip -9 '#{file}'`.chomp
          warn(cmdo) unless cmdo.empty?
          changed = true
        end
      end
      if changed
        d.add_result(:cds, true, force: true)
        sr = d.result(:stats) and sr.remove!
      end
    end
    cli.say
  end

  ##
  # Perform essential-genes operation with MiGA::Cli +cli+
  def check_ess(cli)
    cli.say 'Looking for unarchived essential genes'
    cli.load_project.each_dataset do |d|
      res = d.result(:essential_genes)
      next if res.nil?

      dir = res.file_path(:collection)
      if dir.nil?
        cli.say "  > Removing #{d.name}:essential_genes"
        res.remove!
        sr = d.result(:stats) and sr.remove!
        next
      end
      next if Dir["#{dir}/*.faa"].empty?

      cli.say "  > Fixing #{d.name}"
      cmdo = `cd '#{dir}' && tar -zcf proteins.tar.gz *.faa && rm *.faa`.chomp
      warn(cmdo) unless cmdo.empty?
    end
  end

  ##
  # Perform mytaxa-scan operation with MiGA::Cli +cli+
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
      %i[blast mytaxain wintax gene_ids region_ids].each do |ext|
        file = res.file_path(ext)
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

  ##
  # Perform start operation with MiGA::Cli +cli+
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

  ##
  # Perform taxonomy operation with MiGA::Cli +cli+
  def check_tax(cli)
    # cli.say 'o Checking for taxonomy/distances consistency'
    # TODO: Find 95%ANI clusters with entries from different species
    # TODO: Find different 95%ANI clusters with genomes from the same species
    # TODO: Find AAI values too high or too low for each LCA rank
  end
end
