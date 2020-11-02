# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'net/ftp'
require 'digest/md5'
require 'open-uri'

class MiGA::Cli::Action::GetDb < MiGA::Cli::Action
  def parse_cli
    cli.defaults = {
      database: :recommended,
      version: :latest,
      local: File.expand_path('.miga_db', ENV['MIGA_HOME']),
      host: 'ftp://microbial-genomes.org/db',
      pb: true,
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
        '-h', '--host STRING',
        "Remote host of the database. By default: #{cli[:host]}"
      ) { |v| cli[:db] = v.to_sym }
      opt.on(
        '--list',
        'List available databases and exit'
      ) { |v| cli[:list_databases] = v }
      opt.on(
        '--list-versions',
        'List available versions of the database and exit'
      ) { |v| cli[:list_versions] = v }
      opt.on(
        '--no-overwrite',
        'Exit without downloading if the target database already exists'
      ) { |v| cli[:overwrite] = v }
      opt.on('--no-progress', 'Supress progress bars') { |v| cli[:pb] = v }
    end
  end

  def perform
    @ftp = remote_connection
    manif = remote_manifest(@ftp)
    cli.puts "# Host: #{manif[:host]}"
    cli.puts "# Manifest last update: #{manif[:last_update]}"
    list_databases(manif) and return
    db = db_requested(manif)
    list_versions(db) and return
    ver = version_requested(db)
    check_target and return
    file = download_file(@ftp, ver[:path])
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

  def remote_connection
    cli.say "Connecting to '#{cli[:host]}'"
    uri = URI.parse(cli[:host])
    raise 'Only FTP hosts are supported' unless uri.scheme == 'ftp'

    ftp = Net::FTP.new(uri.host)
    ftp.passive = true
    ftp.login
    ftp.chdir(uri.path)
    ftp
  end

  def download_file(ftp, path)
    cli.say "Downloading '#{path}'"
    Dir.mkdir(cli[:local]) unless Dir.exist? cli[:local]
    file = File.expand_path(path, cli[:local])
    filesize = ftp.size(path)
    transferred = 0
    ftp.getbinaryfile(path, file, 1024) do |data|
      if cli[:pb]
        transferred += data.size
        cli.advance("#{path}:", transferred, filesize)
      end
    end
    cli.print "\n" if cli[:pb]
    file
  end

  def remote_manifest(ftp)
    file = download_file(ftp, '_manif.json')
    MiGA::Json.parse(file)
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

    file = File.expand_path(cli[:database].to_s, cli[:local])
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
    `cd "#{cli[:local]}" && tar -zxf "#{file}"`
  end

  def register_database(manif, db, ver)
    cli.say "Registering database locally"
    local_manif = File.expand_path('_local_manif.json', cli[:local])
    reg = File.exist?(local_manif) ? MiGA::Json.parse(local_manif) : {}
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
