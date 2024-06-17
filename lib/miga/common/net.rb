# frozen_string_literal: true

require 'net/http'
require 'net/ftp'
require 'open-uri'
require 'fileutils'

Net::FTP.send(:remove_const, 'FTP_PORT') # just to avoid warnings
Net::FTP.const_set('FTP_PORT', 21)

##
# General web-access functions shared throughout MiGA.
module MiGA::Common::Net
  attr_accessor :remote_connection_uri

  ##
  # Returns the URL of the host +name+ (Symbol)
  def known_hosts(name)
    case name.to_sym
    when :miga_online_ftp
      "ftp://#{main_server}//" # <- // to simplify chdir in connection
    when :miga_db
      "ftp://#{main_server}/db"
    when :miga_dist
      "ftp://#{main_server}/dist"
    else
      raise "Unrecognized server name: #{name}"
    end
  end

  ##
  # Returns the address of the main MiGA server
  def main_server
    'gatech.microbial-genomes.org'
  end

  ##
  # Connect to an FTP +host+ (String), a known host name (Symbol, see
  # +.known_hosts+), or a parsed +URI+ object
  #
  # Sets the attribute +remote_connection_uri+ to the parsed +URI+ object
  # silently
  def remote_connection(host)
    host = known_hosts(host) if host.is_a?(Symbol)
    uri = host.is_a?(URI) ? host : URI.parse(host)
    @remote_connection_uri = uri

    case uri.scheme
    when 'ftp'
      ftp = Net::FTP.new(uri.host)
      ftp.passive = true
      ftp.resume  = true
      ftp.login
      ftp.chdir(uri.path) unless host.is_a?(URI)
      ftp
    when 'http', 'https'
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 600
      http.use_ssl = uri.scheme == 'https'
      http
    else
      raise 'Only FTP, HTTP, and HTTPS are currently supported'
    end
  end

  ##
  # Download a file via FTP using the +connection+ (returned by
  # +.remote_connection+) with remote name +file+ into local +target+. If +file+
  # is +nil+, it tries to guess the file from +connection+. If +target+ is
  # +nil+, it returns the read data instead
  #
  # Alternatively, +connection+ can simply be the host (String), a recognized
  # Symbol (see +.remote_connection+), or a parsed +URI+ object, in which case
  # the function opens the connection automatically
  #
  # Reports progress to the function block with two arguments: the
  # currently transferred size and the total file size
  def download_file_ftp(connection, file = nil, target = nil)
    # Open connection unless passed
    close_conn = false
    if connection.is_a?(String) || connection.is_a?(Symbol) ||
          connection.is_a?(URI)
      connection = remote_connection(connection)
      file ||= remote_connection_uri.path
      close_conn = true
    end

    # Prepare download
    FileUtils.mkdir_p(File.dirname(target)) if target
    filesize = connection.size(file)
    transferred =
      target && connection.resume && File.exist?(target) ? File.size(target) : 0

    # Get in chunks of 1KiB
    ret = ''
    connection.getbinaryfile(file, target, 1024) do |data|
      yield(transferred += data.size, filesize) if block_given?
      ret += data unless target
    end

    # Close connection if automatically opened
    connection.close if close_conn
    ret unless target
  end

  ##
  # Submit an HTTP or HTTPS request using +url+, which should be a URL
  # either as String or parsed URI. The request follows the +method+, which
  # should be a Net::HTTP verb such as +:get+, +:post+, or +:patch+. All
  # additional parameters for the corresponding method should be passed as
  # +opts+.
  def http_request(method, url, *opts)
    doc = nil
    remote_connection(url).start do |http|
      res = http.send(method, remote_connection_uri.to_s, *opts)
      if %w[301 302].include?(res.code)
        DEBUG "REDIRECTION #{res.code}: #{res['location']}"
        return http_request(method, res['location'], *opts)
      end
      res.value # To force exception unless success
      doc = res.body
    end
    doc
  end

  def net_method(method, uri, *opts)
    attempts ||= 0
    uri = URI.parse(uri) if uri.is_a? String
    DEBUG "#{method.to_s.upcase}: #{uri} #{opts}"
    case method.to_sym
    when :ftp
      download_file_ftp(uri, *opts)
    else
      http_request(method, uri, *opts)
    end
  rescue => e
    raise e if (attempts += 1) >= 3

    sleep 5 # <- For: 429 Too Many Requests
    DEBUG "RETRYING after: #{e}"
    retry
  end

  alias :https_request :http_request

  ##
  # Normalize the encoding of +body+ to UTF-8 by attempting several
  # common recodings. Code from https://github.com/seq-code/registry
  def normalize_encoding(body)
    # Test encodings
    body.force_encoding('utf-8')
    %w[iso8859-1 windows-1252 us-ascii ascii-8bit].each do |enc|
      break if body.valid_encoding?
      recode = body.force_encoding(enc).encode('utf-8')
      body = recode if recode.valid_encoding?
    end
    # If nothing works, replace offending characters with '?'
    unless body.valid_encoding?
      body = body.encode(
        'utf-8', invalid: :replace, undef: :replace, replace: '?'
      )
    end
    body
  end
end
