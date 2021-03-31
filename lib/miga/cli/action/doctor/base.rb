require 'miga/cli/action'
require 'miga/sqlite'

class MiGA::Cli::Action::Doctor < MiGA::Cli::Action
end

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
        next unless [1, 2].map { |i| p.dataset(r[i]).nil? }.any?

        [1, 2].each do |i|
          if p.dataset(r[i]).nil? || !p.dataset(r[i]).active?
            notok[r[i]] = true
          else
            fix[r[i]] = true
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
  # Reads all the distance estimates in +a+ -> *, and saves them in the
  # in the hash +dist+ (also returned)
  def read_bidirectional(a, dist)
    each_database_file(a) do |db_file, metric, result, rank|
      next if rank == :haai # No need for hAAI to be bidirectional

      sql = "select seq2, #{metric}, sd, n, omega from #{metric}"
      data = MiGA::SQLite.new(db_file).run(sql)
      next if data.nil? || data.empty?

      dist[rank][a.name] ||= {}
      data.each { |row| dist[rank][a.name][row.shift] = row }
    end
    return dist
  end

  ##
  # Saves all the distance estimates in * -> +a+ into the +a+ databases
  # (as +a+ -> *), where +a+ is a MiGA::Dataset object, with currently
  # saved values read from the hash +dist+
  def save_bidirectional(a, dist)
    each_database_file(a) do |db_file, metric, result, rank|
      next if rank == :haai # No need for hAAI to be bidirectional

      b2a = dist[rank].map { |b_name, v| b_name if v[a.name] }.compact
      a2b = dist[rank][a.name]&.keys || []
      SQLite3::Database.new(db_file) do |db|
        sql = <<~SQL
          insert into #{metric}(seq1, seq2, #{metric}, sd, n, omega) \
          values(?, ?, ?, ?, ?, ?);
        SQL
        db.execute('BEGIN TRANSACTION;')
        (b2a - a2b).each do |b_name|
          db.execute(sql, [a.name, b_name] + dist[rank][b_name][a.name])
        end
        db.execute('COMMIT;')
      end
    end
  end
end
