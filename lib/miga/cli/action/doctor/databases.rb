
module MiGA::Cli::Action::Doctor::Databases
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
end
