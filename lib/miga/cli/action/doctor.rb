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
    ess: ['essential-genes', 'Check for outdated essential genes'],
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
    p = cli.load_project
    n = p.dataset_names.size
    (0 .. cli[:threads] - 1).map do |i|
      Process.fork do
        k = 0
        cli.load_project.each_dataset do |d|
          k += 1
          cli.advance('Datasets:', k, n, false) if i == 0
          d.recalculate_status if k % cli[:threads] == i
        end
      end
    end
    Process.waitall
    cli.say
  end

  ##
  # Perform databases operation with MiGA::Cli +cli+
  def check_db(cli)
    cli.say 'Checking integrity of databases'
    p = cli.load_project
    n = p.dataset_names.size
    (0 .. cli[:threads] - 1).map do |i|
      Process.fork do
        k = 0
        p.each_dataset do |d|
          k += 1
          cli.advance('Datasets:', k, n, false) if i == 0
          next unless k % cli[:threads] == i
          each_database_file(d) do |db_file, metric, result, _rank|
            check_sqlite3_database(db_file, metric) do
              cli.say(
                "  > Removing malformed database from #{d.name}:#{result}   "
              )
              File.unlink(db_file)
              r = d.result(result) or next
              [r.path(:done), r.path].each do |f|
                File.unlink(f) if File.exist?(f)
              end
            end
          end
        end
      end
    end
    Process.waitall
    cli.say
  end

  ##
  # Perform bidirectional operation with MiGA::Cli +cli+
  def check_bidir(cli)
    cli.say 'Checking if reference distances are bidirectional'
    project = cli.load_project
    ref_ds = project.each_dataset.select(&:ref?)
    ref_names = ref_ds.map(&:name)
    n = ref_ds.size

    # Read data first (threaded)
    tmp = File.join(project.path, 'doctor-bidirectional.tmp')
    FileUtils.mkdir_p(tmp)
    MiGA::Parallel.process(cli[:threads]) do |thr|
      file = File.join(tmp, "#{thr}.json")
      fh = File.open(file, 'w')
      [:aai, :ani].each do |metric|
        fh.puts "# #{metric}"
        ref_ds.each_with_index do |ds, idx|
          if idx % cli[:threads] == thr
            cli.advance('Reading:', idx + 1, n, false) if thr == 0
            row = read_bidirectional(ds, metric)
            fh.puts "#{ds.name} #{JSON.fast_generate(row)}" unless row.empty?
          end
        end
      end
      fh.puts '# end'
      fh.flush # necessary for large threaded runs
      fh.close
      if thr == 0
        cli.advance('Reading:', n, n, false)
        cli.say
      end
    end

    # Merge pieces per thread
    dist = { aai: {}, ani: {} }
    cli[:threads].times do |i|
      cli.advance('Merging:', i + 1, cli[:threads], false)
      file = File.join(tmp, "#{i}.json")
      File.open(file, 'r') do |fh|
        metric = nil
        fh.each do |ln|
          qry, row = ln.chomp.split(' ', 2)
          if qry == '#'
            metric = row.to_sym
          else
            raise "Unrecognized metric: #{metric}" unless dist[metric]
            JSON.parse(row).each do |sbj, val|
              dist[metric][qry] ||= {}
              if dist[metric][sbj]&.include?(qry)
                dist[metric][sbj].delete(qry) # Already bidirectional
              else
                dist[metric][qry][sbj] = val
              end
            end
          end
        end
        raise "Incomplete thread dump: #{file}" unless metric == :end
      end
    end
    cli.say
    FileUtils.rm_rf(tmp)

    # Write missing values (threaded)
    MiGA::Parallel.distribute(ref_ds, cli[:threads]) do |ds, idx, thr|
      cli.advance('Datasets:', idx + 1, n, false) if thr == 0
      save_bidirectional(ds, dist)
    end
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
          run_cmd(['gzip', '-9', file])
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
    cli.say 'Looking for outdated essential genes'
    cli.load_project.each_dataset do |d|
      res = d.result(:essential_genes)
      next if res.nil?

      dir = res.file_path(:collection)
      if dir.nil? || outdated_fastaai_ess(res)
        cli.say "  > Removing #{d.name}:essential_genes"
        res.remove!
        d.result(:stats)&.remove!
        next
      end
      next if Dir["#{dir}/*.faa"].empty?

      cli.say "  > Fixing #{d.name}"
      run_cmd <<~CMD
        cd #{dir.shellescape} && tar -zcf proteins.tar.gz *.faa && rm *.faa
      CMD
    end
  end

  ##
  # Check if the essential genes result +res+ has an outdated FastAAI index
  def outdated_fastaai_ess(res)
    idx1 = res.file_path(:fastaai_index)   # Carlos' original format
    idx2 = res.file_path(:fastaai_index_2) # Kenji's first format
    idx3 = res.file_path(:fastaai_index_3) # v0.1.17
    idx3.nil? && (!idx2.nil? || !idx1.nil?)
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
          run_cmd <<~CMD
            cd #{dir.shellescape}/.. \
                && tar -zcf '#{d.name}.reg.tar.gz' '#{d.name}.reg' \
                && rm -r '#{d.name}.reg'
          CMD
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

  ##
  # Run command +cmd+ with options +opts+
  def run_cmd(cmd, opts = {})
    opts = { return: :output, err2out: true, raise: false }.merge(opts)
    cmdo = MiGA::MiGA.run_cmd(cmd, opts).chomp
    warn(cmdo) unless cmdo.empty?
  end
end
