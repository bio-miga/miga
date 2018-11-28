
require 'sqlite3'

module MiGA::DistanceRunner::Database
  ##
  # Check for corrupt files and create empty databases
  def initialize_dbs!(for_ref)
    @dbs = {}
    @tmp_dbs = {}
    @db_counts = {}
    {haai: :aai, aai: :aai, ani: :ani}.each do |m, t|
      @db_counts[m] = 0
      @dbs[m] = for_ref ? ref_db(m) : query_db(m)
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
      # Initialize if it doesn't exist
      SQLite3::Database.new(dbs[m]) do |conn|
        conn.execute "create table if not exists #{t}(" +
            "seq1 varchar(256), seq2 varchar(256), " +
            "#{t} float, sd float, n int, omega int" +
          ")"
      end unless File.size? dbs[m]
      # Copy over to (local) temporals
      @tmp_dbs[m] = tmp_file("#{m}.db")
      FileUtils.cp(dbs[m], tmp_dbs[m])
    end
  end

  ##
  # Path to the database +metric+ for +dataset_name+ in +project+
  # (assumes that +dataset_name+ is a reference dataset)
  def ref_db(metric, dataset_name=nil)
    dataset_name ||= dataset.name
    b = case metric
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
    return y unless y.nil? or y.zero?

    # Check if self.dataset <- target is done (another thread)
    if dataset.is_ref? and project.path == ref_project.path
      y = data_from_db(
        target.name, dataset.name, ref_db(metric, target.name), metric)
      unless y.nil? or y.first.zero?
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
    SQLite3::Database.new(db) do |conn|
      y = conn.execute(
        "select #{metric}, sd, n, omega from #{metric} where seq1=? and seq2=?",
        [n1, n2]).first
    end if File.size? db
    y
  end

  ##
  # Save +data+ of +metric+ between +n1+ and +n2+ in the +db+ database.
  def data_to_db(n1, n2, db, metric, data)
    SQLite3::Database.new(db) do |conn|
      conn.execute(
        "insert into #{metric} (seq1, seq2, #{metric}, sd, n, omega) " +
        "values (?, ?, ?, ?, ?, ?)", [n1, n2] + data)
    end
    checkpoint metric
  end

  ##
  # Iterates for each entry in +db+
  def foreach_in_db(db, metric, &blk)
    SQLite3::Database.new(db) do |conn|
      conn.execute("select * from #{metric}").each{ |r| blk[r] }
    end
  end
end
