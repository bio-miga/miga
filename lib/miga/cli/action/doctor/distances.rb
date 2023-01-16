
module MiGA::Cli::Action::Doctor::Distances
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
end

