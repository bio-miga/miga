# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'digest/md5'

class MiGA::Cli::Action::Db < MiGA::Cli::Action
  def parse_cli
    cli.defaults = {
      database: :recommended,
      version: :latest,
      local: File.expand_path('.miga_db', ENV['MIGA_HOME']),
      host: MiGA::MiGA.known_hosts(:miga_db),
      pb: true,
      reuse_archive: false,
      overwrite: true
    }
    cli.parse do |opt|
      opt.on(
        '-n', '--database STRING',
        "Name of the database to download. By default: #{cli[:database]}"
      ) { |v| cli[:database] = v.to_sym }
      opt.on(
        '--db-version STRING',
        "Database version to download. By default: #{cli[:version]}"
      ) { |v| cli[:version] = v.to_sym }
      opt.on(
        '-l', '--local-dir PATH',
        "Local directory to store the database. By default: #{cli[:local]}"
      ) { |v| cli[:local] = v }
      opt.on(
        '--host STRING',
        "Remote host of the database. By default: #{cli[:host]}"
      ) { |v| cli[:host] = v }
      opt.on(
        '--list',
        'List available databases and exit'
      ) { |v| cli[:list_databases] = v }
      opt.on(
        '--list-versions',
        'List available versions of the database and exit'
      ) { |v| cli[:list_versions] = v }
      opt.on(
        '--list-local',
        'List only the versions of the local databases (if any) and exit'
      ) { |v| cli[:list_local] = v }
      opt.on(
        '--reuse-archive',
        'Reuse a previously downloaded archive if available'
      ) { |v| cli[:reuse_archive] = v }
      opt.on(
        '--no-overwrite',
        'Exit without downloading if the target database already exists'
      ) { |v| cli[:overwrite] = v }
      opt.on(
        '--tab',
        'Return a tab-delimited table'
      ) { |v| cli[:tabular] = v }
      opt.on('--no-progress', 'Supress progress bars') { |v| cli[:pb] = v }
    end
  end

  def perform
    # Quick check when the database is not an alias
    dir = File.join(cli[:local], cli[:database].to_s)
    if !cli[:overwrite] && Dir.exist?(dir)
      cli.puts "Database exists: #{dir}"
      return
    end

    # If dealing with local checks only
    if cli[:list_local]
      list_local
      return
    end

    # Remote manifest
    @ftp = remote_connection
    manif = remote_manifest(@ftp)
    cli.puts "# Host: #{manif[:host]}"
    cli.puts "# Manifest last update: #{manif[:last_update]}"
    list_databases(manif) and return
    db = db_requested(manif)
    list_versions(db) and return
    ver = version_requested(db)
    check_target and return

    # Download and expand
    file = download_file(@ftp, ver[:path], cli[:reuse_archive])
    check_digest(ver, file)
    unarchive(file)
    register_database(manif, db, ver)
  end

  def empty_action
    cli.puts 'Downloading latest version of the default database'
  end

  def complete
    @ftp.close unless @ftp.nil?
    super
  end

  private

  def list_local
    local_manif = local_manifest
    raise "Local manifest not found." unless local_manif
    databases =
      if %i[recommended test].include?(cli[:database])
        local_manif[:databases].keys
      else
        [cli[:database].to_sym]
      end
    cli.table(
      %w[database version genomes updated path],
      databases.map do |db|
        path = File.join(cli[:local], db.to_s)
        p = MiGA::Project.load(path)
        if p
          md = p.metadata
          [db, md[:release], md[:datasets].count, md[:updated], p.path]
        end
      end.compact
    )
  end

  def remote_connection
    cli.say "Connecting to '#{cli[:host]}'"
    MiGA::MiGA.remote_connection(cli[:host])
  end

  def download_file(ftp, path, reuse = false)
    cli.say "Downloading '#{path}'"
    file = File.expand_path(path, cli[:local])
    if reuse && File.exist?(file)
      cli.say "Reusing #{file}"
    else
      MiGA::MiGA.download_file_ftp(ftp, path, file) do |n, size|
        cli.advance("#{path}:", n, size) if cli[:pb]
      end
      cli.print "\n" if cli[:pb]
    end
    file
  end

  def remote_manifest(ftp)
    file = download_file(ftp, '_manif.json')
    MiGA::Json.parse(file)
  end

  def local_manifest
    file = File.join(cli[:local], '_local_manif.json')
    MiGA::Json.parse(file) if File.exist?(file)
  end

  def db_requested(manif)
    [:recommended, :test].each do |n|
      if cli[:database] == n
        raise "This host has no #{n} database" if manif[n].nil?

        cli[:database] = manif[n].to_sym
      end
    end
    db = manif[:databases][cli[:database]]
    raise 'Cannot find database in this host' if db.nil?

    db
  end

  def version_requested(db)
    if cli[:version] == :latest
      cli[:version] = db[:latest].to_sym
    end
    ver = db[:versions][cli[:version]]
    raise 'Cannot find database version' if ver.nil?

    cli.puts "# Database size: #{version_size(ver)}"
    ver
  end

  def list_databases(manif)
    return false unless cli[:list_databases]

    cli.puts "# Recommended database: #{manif[:recommended]}"
    cli.puts ''
    cli.table(
      %w[name description latest versions],
      manif[:databases].map do |name, i|
        [name, i[:description], i[:latest], i[:versions].size.to_s]
      end
    )
    true
  end

  def list_versions(db)
    return false unless cli[:list_versions]

    cli.puts "# Database: #{cli[:database]}"
    cli.puts ''
    cli.table(
      %w[version updated size datasets],
      db[:versions].map do |name, i|
        [name, i[:last_update], version_size(i), i[:datasets]]
      end
    )
    true
  end

  def check_target
    return false if cli[:overwrite]

    file = File.join(cli[:local], cli[:database].to_s)
    if Dir.exist? file
      warn "The target directory already exists: #{file}"
      true
    else
      false
    end
  end

  def check_digest(ver, file)
    cli.say 'Checking MD5 digest'
    cli.say "Expected: #{ver[:MD5]}"
    md5 = Digest::MD5.new
    File.open(file, 'rb') do |fh|
      until fh.eof?
        md5.update fh.read(1024)
      end
    end
    dig = md5.hexdigest
    cli.say "Observed: #{dig}"
    raise 'Corrupt file, MD5 does not match' unless dig == ver[:MD5]
  end

  def version_size(ver)
    cli.num_suffix(ver[:size], true) + ' (' +
      cli.num_suffix(ver[:size_unarchived], true) + ')'
  end

  def unarchive(file)
    cli.say "Unarchiving #{file}"
    MiGA::MiGA.run_cmd <<~CMD
      cd #{cli[:local].shellescape} \
        && tar -zxf #{file.shellescape} \
        && rm #{file.shellescape}
    CMD
  end

  def register_database(manif, db, ver)
    cli.say "Registering database locally"
    local_manif = local_manifest || {}
    reg[:last_update] = Time.now.to_s
    reg[:databases] ||= {}
    reg[:databases][cli[:database]] ||= {}
    reg[:databases][cli[:database]][:manif_last_update] = manif[:last_update]
    reg[:databases][cli[:database]][:manif_host] = manif[:host]
    db.each { |k, v| reg[:databases][cli[:database]][k] = v }
    reg[:databases][cli[:database]][:local_version] = ver
    MiGA::Json.generate(reg, local_manif)
  end
end
