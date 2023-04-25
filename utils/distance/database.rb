require 'miga/sqlite'

module MiGA::DistanceRunner::Database
  ##
  # Check for corrupt files and create empty databases
  def initialize_dbs!(for_ref)
    $stderr.puts "Initializing databases (for_ref = #{for_ref})"
    @dbs = {}
    @tmp_dbs = {}
    @db_counts = {}
    { haai: :aai, aai: :aai, ani: :ani }.each do |m, t|
      @db_counts[m] = 0
      @dbs[m] = for_ref ? ref_db(m) : query_db(m)
      @tmp_dbs[m] = tmp_file("#{m}.db")

      # Remove if corrupt
      if File.size?(dbs[m])
        begin
          SQLite3::Database.new(dbs[m]) do |conn|
            conn.execute "select count(*) from #{t};"
          end
        rescue SQLite3::SQLException
          FileUtils.rm dbs[m]
        end
      end

      # Initialize if it doesn't exist, copy otherwise
      if File.size? dbs[m]
        FileUtils.cp(dbs[m], tmp_dbs[m])
      else
        SQLite3::Database.new(tmp_dbs[m]) do |conn|
          conn.execute <<~SQL
            create table if not exists #{t}(
              seq1 varchar(256), seq2 varchar(256),
              #{t} float, sd float, n int, omega int
            )
          SQL
        end
        FileUtils.cp(tmp_dbs[m], dbs[m]) unless opts[:only_domain]
      end
    end
  end

  ##
  # Path to the database +metric+ for +dataset_name+ in +project+
  # (assumes that +dataset_name+ is a reference dataset)
  def ref_db(metric, dataset_name = nil)
    dataset_name ||= dataset.name
    b =
      case metric
      when :haai
        "01.haai/#{dataset_name}.db"
      when :aai
        "02.aai/#{dataset_name}.db"
      when :ani
        "03.ani/#{dataset_name}.db"
      end
    File.expand_path(b, home)
  end

  ##
  # Path to the database +metric+ for +dataset+ (assumes that +dataset+ is a
  # query dataset)
  def query_db(metric)
    File.expand_path("#{dataset.name}.#{metric}.db", home)
  end

  ##
  # Get the stored +metric+ value against +target+
  def stored_value(target, metric)
    # Check if self.dataset -> target is done (previous run)
    y = value_from_db(dataset.name, target.name, tmp_dbs[metric], metric)
    return y unless y.nil? || y.zero?

    # Check if self.dataset <- target is done (another thread)
    if dataset.ref? && project.path == ref_project.path
      y = data_from_db(
        target.name, dataset.name, ref_db(metric, target.name), metric
      )
      unless y.nil? || y.first.nil? || y.first.zero?
        # Store a copy
        data_to_db(dataset.name, target.name, tmp_dbs[metric], metric, y)
        return y.first
      end
    end
    nil
  end

  ##
  # Get the value of +metric+ in the +db+ database between +n1+ and +n2+
  def value_from_db(n1, n2, db, metric)
    y = data_from_db(n1, n2, db, metric)
    y.first unless y.nil?
  end

  ##
  # Get the +metric+ data in the +db+ database between +n1+ and +n2+. Returns an
  # Array with the metric, standard deviation, number of matches, and maximum
  # possible number of matches
  def data_from_db(n1, n2, db, metric)
    y = nil
    table = metric == :haai ? :aai : metric
    SQLite3::Database.new(db) do |conn|
      y = conn.execute(
        "select #{table}, sd, n, omega from #{table} where seq1=? and seq2=?",
        [n1, n2]
      ).first
    end if File.size?(db)
    y
  rescue SQLite3::CorruptException => e
    $stderr.puts "Corrupt database: #{db}"
    raise e
  end

  ##
  # Save +data+ of +metric+ between +n1+ and +n2+ in the +db+ database.
  def data_to_db(n1, n2, db, metric, data)
    table = metric == :haai ? :aai : metric
    SQLite3::Database.new(db) do |conn|
      conn.execute(
        "insert into #{table} (seq1, seq2, #{table}, sd, n, omega) " +
        "values (?, ?, ?, ?, ?, ?)", [n1, n2] + data
      )
    end
    checkpoint metric
  end

  ##
  # Saves +data+ of +metric+ in batch to the temporary database,
  # and assumes query is +#dataset+. +data+ must be a hash with target names
  # as key and arrays as values with: [val, sd, n, omega]
  def batch_data_to_db(metric, data)
    db = tmp_dbs[metric]
    table = metric == :haai ? :aai : metric
    SQLite3::Database.new(db) do |conn|
      conn.execute('BEGIN TRANSACTION')
      data.each do |k, v|
        sql = <<~SQL
                insert into #{table} (
                  seq1, seq2, #{table}, sd, n, omega
                ) values (?, ?, ?, ?, ?, ?)
              SQL
        conn.execute(sql, [dataset.name, k] + v)
      end
      conn.execute('COMMIT')
    end
    checkpoint(metric)
  end

  ##
  # Retrieves data of +metric+ in batch from the temporary database,
  # and assumes query is +#dataset+. The output data is a hash with the same
  # structure described for +#batch_data_to_db+
  def batch_data_from_db(metric)
    db = tmp_dbs[metric]
    table = metric == :haai ? :aai : metric
    data = {}
    SQLite3::Database.new(db) do |conn|
      sql = "select seq2, #{table}, sd, n, omega from #{table}"
      conn.execute(sql).each { |row| data[row.shift] = row }
    end
    data
  rescue => e
    $stderr.puts "Database file: #{db}" if db ||= nil
    raise e
  end

  ##
  # Retrieve the name and AAI of the closest relative from the AAI database
  def closest_relative
    db = tmp_dbs[:aai]
    sql = 'select seq2, aai from aai order by aai desc limit 1'
    MiGA::SQLite.new(db).run(sql).first
  rescue => e
    $stderr.puts "Database file: #{db}" if db ||= nil
    raise e
  end

  ##
  # Retrieve only +metric+ values against +names+
  def batch_values_from_db(metric, names)
    data = batch_data_from_db(metric)
    names.map { |i| data[i]&.first }
  end

  ##
  # Iterates for each entry in +db+
  def foreach_in_db(db, metric, &blk)
    SQLite3::Database.new(db) do |conn|
      conn.execute("select * from #{metric}").each { |r| blk[r] }
    end
  end

  ##
  # Select only those targets that are not yet stored in either direction
  def pending_targets(targets, metric)
    saved = batch_data_from_db(metric).keys
    targets
      .compact
      .select { |i| !saved.include?(i.name) }
      .select { |i| !stored_value(i, metric)&.> 0.0 }
  end
end
