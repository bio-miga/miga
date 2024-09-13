
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

    # Read and write data
    tmp = partial_bidir_tmp(project, ref_ds)
    fixed_ds = merge_bidir_tmp(tmp)
    FileUtils.rm_rf(tmp)

    # Fix tables if needed
    unless fixed_ds.empty?
      cli.say ' - Filled datasets: %i' % fixed_ds.size
      %i[aai_distances ani_distances].each do |res_name|
        res = cli.load_project.result(res_name) or next
        cli.say ' - Recalculating tables: %s' % res_name
        res.recalculate!('Distances updated for bidirectionality').save
      end
    end
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

  #---- Auxuliary functions -----

  ##
  # Calculates the number of chunks that should be produced during the
  # bidirectional checks for +n+ reference datasets (Integer)
  def partial_bidir_chunks(n)
    y = [cli[:threads], (n / 1024).ceil].max
    y = n if y > n
    y
  end

  ##
  # Make a temporal directory holding partial bidirectionality reports (one per
  # thread) in a custom multi-JSON format. Requires a MiGA::Project +project+
  # and the iterator of the reference datasets +ref_ds+. Returns the path to the
  # temporal directory created
  def partial_bidir_tmp(project, ref_ds)
    n = ref_ds.size
    chunks = partial_bidir_chunks(n)

    # Check first if a previous run is complete (and recover it)
    tmp = File.join(project.path, 'doctor-bidirectional.tmp')
    tmp_chunks = File.join(tmp, 'chunks.txt')
    tmp_chunks_val = [chunks, 0]
    if File.size?(tmp_chunks)
      tmp_chunks_val = File.readlines(tmp_chunks).map(&:chomp).map(&:to_i)
    end
    chunks = tmp_chunks_val[0]
    FileUtils.rm_rf(tmp) unless tmp_chunks_val[1] == n

    # Read data (threaded)
    FileUtils.mkdir_p(tmp)
    chunks_e = 0 .. chunks - 1
    o = MiGA::Parallel.distribute(chunks_e, cli[:threads]) do |chunk, k, thr|
      cli.advance('Reading:', k, chunks, false) if thr == 0
      dist = {}
      [:aai, :ani].each do |metric|
        dist[metric] = {}
        ref_ds.each_with_index do |ds, idx|
          if idx % chunks == chunk
            row = read_bidirectional(ds, metric)
            dist[metric][ds.name] = row unless row.empty?
          end
        end
      end
      file = File.join(tmp, "#{chunk}.marshal")
      File.open("#{file}.tmp", 'w') { |fh| Marshal.dump(dist, fh) }
      File.rename("#{file}.tmp", file)
    end
    cli.advance('Reading:', chunks, chunks, false)
    cli.say
    MiGA::Parallel.assess_success(o)

    # Save information to indicate that the run is complete and return
    File.open(tmp_chunks, 'w') { |fh| fh.puts(chunks, n) }
    return tmp
  end

  ##
  # Read partial temporal reports of bidirectionality (located in +tmp+), and
  # fill databases with missing values. Returns the names of the datasets fixed
  # as a Set.
  def merge_bidir_tmp(tmp)
    tmp_done = File.join(tmp, 'chunks.txt')
    chunks = File.readlines(tmp_done)[0].chomp.to_i

    lower_tr = []
    chunks.times.each do |i|
      (0 .. i).to_a.each { |j| lower_tr << [i, j] }
    end
    o = MiGA::Parallel.distribute(lower_tr, cli[:threads]) do |cell, k, thr|
      cli.advance('Writing:', k, lower_tr.size, false) if thr == 0
      done_f = File.join(tmp, "#{cell[0]}-#{cell[1]}.txt")
      next if File.exist?(done_f)

      fixed_ds = merge_bidir_tmp_pair(tmp, cell[0], cell[1])
      File.open("#{done_f}.tmp", 'w') { |fh| fixed_ds.each { |ds| fh.puts ds } }
      File.rename("#{done_f}.tmp", done_f)
    end
    cli.advance('Writing:', lower_tr.size, lower_tr.size, false)
    cli.say
    MiGA::Parallel.assess_success(o)

    lower_tr.map do |cell|
      Set.new.tap do |y|
        file = File.join(tmp, "#{cell[0]}-#{cell[1]}.txt")
        raise MiGA::Error.new(
          "Expected file missing, probably due to a thread failure: #{file}"
        ) unless File.exist?(file)
        File.open(file, 'r') { |fh| fh.each { |ln| y << ln.chomp } }
      end
    end.inject(Set.new, :+)
  end

  ##
  # Cross-reference two reports of bidirectionality (located in +tmp+),
  # identified by indexes +x+ and +y+, and fill databases with missing values.
  # Returns the names of the fixed datasets as a Set.
  def merge_bidir_tmp_pair(tmp, x, y)
    dist_x = Marshal.load(File.read(File.join(tmp, "#{x}.marshal")))
    if x == y
      merge_bidir_tmp_cell(dist_x, dist_x)
    else
      dist_y = Marshal.load(File.read(File.join(tmp, "#{y}.marshal")))
      merge_bidir_tmp_cell(dist_x, dist_y) +
      merge_bidir_tmp_cell(dist_y, dist_x)
    end
  end

  ##
  # Find missing values in a "chunks cell" and fill databases. Returns the names
  # of the fixed datasets as a Set.
  def merge_bidir_tmp_cell(dist_x, dist_y)
    # Find missing values
    dist = {}
    datasets = Set.new
    dist_x.each do |metric, distances_x|
      dist[metric] = {}
      distances_x.each do |qry_x, row_x|
        dist_y[metric].each do |qry_y, row_y|
          # Ignore if missing in dist_x
          next unless dist_x[metric][qry_x]&.include?(qry_y)
          # Ignore if already in dist_y
          next if dist_y[metric][qry_y]&.include?(qry_x)
          # Save otherwise
          dist[metric][qry_x] ||= {}
          dist[metric][qry_x][qry_y] = dist_x[metric][qry_x][qry_y]
          datasets << qry_y
        end
      end
    end

    # Save them in databases
    datasets.each do |ds_name|
      ds = cli.load_project.dataset(ds_name)
      save_bidirectional(ds, dist)
    end
    datasets
  end
end

