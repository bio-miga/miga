# @package MiGA
# @license Artistic-2.0

require 'sqlite3'

##
# SQLite3 wrapper for MiGA.
class MiGA::SQLite < MiGA::MiGA
  class << self
    ##
    # Default parsing options. Supported +opts+ keys:
    # - +:busy_attempts+: Number of times to retry when database is busy
    #   (default: 3)
    def default_opts(opts = {})
      opts[:busy_attempts] ||= 3
      opts
    end
  end

  ##
  # Options hash
  attr :opts

  ##
  # Database absolute path
  attr :path

  ##
  # Create MiGA::SQLite with database in +path+ (without opening a connection)
  # and options +opts+ (see +.default_opts+)
  def initialize(path, opts = {})
    @opts = MiGA::SQLite.default_opts(opts)
    @path = File.absolute_path(path)
  end

  ##
  # Executes +cmd+ and returns the result
  def run(*cmd)
    busy_attempts ||= 0
    io_attempts ||= 0
    y = nil
    SQLite3::Database.new(path) { |conn| y = conn.execute(*cmd) }
    y
  rescue SQLite3::BusyException => e
    busy_attempts += 1
    raise "Database busy #{path}: #{e.message}" if busy_attempts >= 3

    sleep(1)
    retry
  rescue SQLite3::IOException => e
    io_attempts += 1
    raise "Database I/O error #{path}: #{e.message}" if io_attempts >= 3

    sleep(1)
    retry
  end
end
