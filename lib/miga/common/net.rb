# frozen_string_literal: true

require 'net/ftp'
require 'open-uri'
require 'fileutils'

Net::FTP.send(:remove_const, 'FTP_PORT') # just to avoid warnings
Net::FTP.const_set('FTP_PORT', 21)

##
# General web-access functions shared throughout MiGA.
module MiGA::Common::Net
  ##
  # Returns the URL of the host +name+ (Symbol)
  def known_hosts(name)
    case name.to_sym
    when :miga_online_ftp
      'ftp://microbial-genomes.org//' # <- // to simplify chdir in connection
    when :miga_db
      'ftp://microbial-genomes.org/db'
    when :miga_dist
      'ftp://microbial-genomes.org/dist'
    else
      raise "Unrecognized server name: #{host}"
    end
  end

  ##
  # Connect to an FTP +host+ (String) or a known host name (Symbol, see
  # +.known_hosts+)
  def remote_connection(host)
    host = known_hosts(host) if host.is_a?(Symbol)
    uri = URI.parse(host)
    raise 'Only FTP hosts are currently supported' unless uri.scheme == 'ftp'

    ftp = Net::FTP.new(uri.host)
    ftp.passive = true
    ftp.login
    ftp.chdir(uri.path)
    ftp
  end

  ##
  # Download a file via FTP using the +connection+ (returned by
  # +.remote_connection+) with remote name +file+ into local +target+.
  #
  # Alternatively, +connection+ can simply be the host (String) or a recognized
  # Symbol (see +.remote_connection+), in which case the function opens the
  # connection automatically
  #
  # Reports progress to the function block with two arguments: the
  # currently transferred size and the total file size
  def download_file_ftp(connection, file, target)
    # Open connection unless passed
    close_conn = false
    if connection.is_a?(String) || connection.is_a?(Symbol)
      connection = remote_connection(connection)
      close_conn = true
    end

    # Prepare download
    FileUtils.mkdir_p(File.dirname(target))
    filesize = connection.size(file)
    transferred = 0

    # Get in chunks of 1KiB
    connection.getbinaryfile(file, target, 1024) do |data|
      yield(transferred += data.size, filesize) if block_given?
    end

    # Close connection if automatically opened
    connection.close if close_conn
  end
end
