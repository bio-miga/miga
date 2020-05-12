require 'miga/cli/action'
require 'sqlite3'

class MiGA::Cli::Action::Doctor < MiGA::Cli::Action
end

module MiGA::Cli::Action::Doctor::Base
  ##
  # Check the database in +db_file+ maintains integrity for the
  # tables saving +metric+ (:ani or :aai) and call +blk+ if the
  # file is corrupt or doesn't contain the expected structure
  def check_sqlite3_database(db_file, metric, &blk)
    SQLite3::Database.new(db_file) do |conn|
      conn.execute("select count(*) from #{metric}").first
    end
  rescue SQLite3::SQLException, SQLite3::CorruptException
    blk.call
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
end
