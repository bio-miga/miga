require 'miga/cli/action'
require 'miga/sqlite'

module MiGA::Cli::Action::Doctor::Base
  ##
  # Check the database in +db_file+ maintains integrity for the
  # tables saving +metric+ (:ani or :aai) and call +blk+ if the
  # file is corrupt or doesn't contain the expected structure
  def check_sqlite3_database(db_file, metric, &blk)
    MiGA::SQLite.new(db_file).run("select count(*) from #{metric}")
  rescue SQLite3::SQLException, SQLite3::CorruptException
    blk.call
  end

  def each_database_file(dataset, &blk)
    ref_db = {
      haai: ['01.haai', :aai], aai: ['02.aai', :aai], ani: ['03.ani', :ani]
    }
    qry_db = {
      haai: ['.haai.db', :aai], aai: ['.aai.db', :aai], ani: ['.ani.db', :ani]
    }
    base = File.join(dataset.project.path, 'data', '09.distances')
    result = :distances
    if dataset.ref?
      file_db = "#{dataset.name}.db"
      ref_db.each do |rank, v|
        dir, metric = *v
        file = File.join(base, dir, file_db)
        blk[file, metric, result, rank] if File.exist? file
      end
      # Query databases for reference databases refer to taxonomy runs
      base = File.join(base, '05.taxonomy')
      result = :taxonomy
    end
    qry_db.each do |rank, v|
      ext, metric = *v
      file = File.join(base, "#{dataset.name}#{ext}")
      blk[file, metric, result, rank] if File.exist? file
    end
  end

  ##
  # Scans the all-vs-all matrix registered in +res+ (MiGA::Result) in search of
  # pairs where one or both datasets are missing or inactive in the project +p+
  # (MiGA::Project), and report progress through +cli+ (MiGA::Cli).
  # Returns an Array with two arrays: the first a list of dataset names that are
  # no longer registered in the project or are currently inactive, and the
  # second a list of dataset names that have registered pairs with the first
  # list, and therefore the databases need to be cleaned.
  # This is a subtask of +check_dist+
  def check_dist_eval(cli, p, res)
    notok = {}
    fix = {}
    Zlib::GzipReader.open(res.file_path(:matrix)) do |fh|
      lineno = 0
      fh.each_line do |ln|
        next if (lineno += 1) == 1

        r = ln.split("\t")
        names = [r[0], r[1]]
        next unless names.any? { |i| p.dataset(i).nil? }

        names.each do |i|
          if p.dataset(i).nil? || !p.dataset(i).active?
            notok[i] = true
          else
            fix[i] = true
          end
        end
      end
    end
    [notok.keys, fix.keys]
  end

  ##
  # Cleanup distance databases for datasets names in +fix+ (Array: String)
  # from project +p+ (MiGA::Project), and report through +cli+ (MiGA::Cli).
  # This is a subtask of +check_dist+
  def check_dist_fix(cli, p, fix)
    return if fix.empty?

    cli.say("- Fixing #{fix.size} datasets")
    fix.each do |d_n|
      cli.say "  > Fixing #{d_n}."
      p.dataset(d_n).cleanup_distances!
    end
  end

  ##
  # Recompute +res+ (MiGA::Result) if +notok+ (Array: String) has any dataset
  # names registered, and report through +cli+ (MiGA::Cli).
  # This is a subtask of +check_dist+
  def check_dist_recompute(cli, res, notok)
    return if notok.empty?

    cli.say '- Unregistered datasets detected: '
    if notok.size <= 5
      notok.each { |i| cli.say "  > #{i}" }
    else
      cli.say "  > #{notok.size}, including #{notok.first}"
    end
    cli.say '- Removing tables, recompute'
    res.remove!
  end

  ##
  # Returns all targets identified by AAI
  def saved_targets(dataset)
    # Return nil if distance or database are not retrievable
    dist = dataset.result(:distances) or return
    path = dist.file_path(:aai_db) or return

    MiGA::SQLite.new(path).run('select seq2 from aai').map(&:first)
  end

  ##
  # Reads all the distance estimates in +a+ -> * for +metric+ and
  # returns them as a hash +{"b_name" => [val, sd, ...], ...}+
  def read_bidirectional(a, metric)
    db_file = a.result(:distances)&.file_path("#{metric}_db") or return {}
    sql = "select seq2, #{metric}, sd, n, omega from #{metric}"
    data = MiGA::SQLite.new(db_file).run(sql) || []
    Hash[
      data.map do |row|
        k, v = row.shift(2)
        [k, row.all?(&:zero?) ? v : [v] + row]
      end
    ]
  end

  ##
  # Saves all the distance estimates in * -> +a+ into the +a+ databases
  # (as +a+ -> *), where +a+ is a MiGA::Dataset object, with currently
  # saved values read from the hash +dist+
  def save_bidirectional(a, dist)
    each_database_file(a) do |db_file, metric, result, rank|
      next if rank == :haai # No need for hAAI to be bidirectional
      next if result == :taxonomy # Taxonomy is never bidirectional

      b2a = dist[rank].map { |b_name, v| b_name if v[a.name] }.compact
      a2b = dist[rank][a.name]&.keys || []
      MiGA::SQLite.new(db_file).run do |db|
        sql = <<~SQL
          insert into #{metric}(seq1, seq2, #{metric}, sd, n, omega) \
          values(?, ?, ?, ?, ?, ?);
        SQL
        db.execute('BEGIN TRANSACTION;')
        (b2a - a2b).each do |b_name|
          val = dist[rank][b_name][a.name]
          val = [val, 0, 0, 0] unless val.is_a?(Array)
          db.execute(sql, [a.name, b_name] + val)
        end
        db.execute('COMMIT;')
      end
    end
  end

  ##
  # Run command +cmd+ with options +opts+
  def run_cmd(cmd, opts = {})
    opts = { return: :output, err2out: true, raise: false }.merge(opts)
    cmdo = MiGA::MiGA.run_cmd(cmd, opts).chomp
    warn(cmdo) unless cmdo.empty?
  end

  ##
  # Check if the essential genes result +res+ has an outdated FastAAI index
  def outdated_fastaai_ess(res)
    idx1 = res.file_path(:fastaai_index)
    idx2 = res.file_path(:fastaai_index_2)
    idx2.nil? && !idx1.nil?
  end
end
