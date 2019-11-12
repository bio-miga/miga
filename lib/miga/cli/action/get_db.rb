# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'net/ftp'

class MiGA::Cli::Action::GetDb < MiGA::Cli::Action

  def parse_cli
    cli.defaults = {
      database: :recommended,
      version: :latest,
      local: File.expand_path('.miga_db', ENV['MIGA_HOME']),
      host: 'ftp://microbial-genomes.org/db',
      pb: true
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
    cli.puts "# Database size: #{version_size(ver)}"
    file = download_file(@ftp, ver[:path])
    # TODO: Check MD5 digest
    # TODO: Unpack
    # TODO: Register
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
    ftp = Net::FTP.open(uri.host, port: uri.port)
    ftp.login
    ftp.chdir(uri.path)
    ftp
  end

  def download_file(ftp, path)
    cli.say "Downloading '#{path}'"
    Dir.mkdir(cli[:local]) unless Dir.exist? cli[:local]
    file = File.expand_path(path, cli[:local])
    filesize = ftp.size(path)
    cli.print(" " * 100, "|\r") if cli[:pb]
    transferred = 0
    last_compl = -1
    ftp.getbinaryfile(path, file, 1024) do |data|
      if cli[:pb]
        transferred += data.size
        compl = ((transferred.to_f/filesize.to_f)*100).to_i
        cli.print("=" * compl.to_i, "> #{compl}%\r") if compl > last_compl
        last_compl = compl
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
    if cli[:database] == :recommended
      raise 'This host has no recommended database' if manif[:recommended].nil?
      cli[:database] = manif[:recommended].to_sym
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

  def version_size(ver)
    '%.1fGb' % (ver[:size].to_f/1e9)
  end
end
