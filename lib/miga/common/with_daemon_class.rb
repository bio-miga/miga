
##
# Helper module with specific class-level functions to be used with
# +include MiGA::Common::WithDaemon+.
module MiGA::Common::WithDaemonClass
  ##
  # Path to the daemon home from the parent's +path+
  def daemon_home(path)
    path
  end

  ##
  # Path to the alive file
  def alive_file(path)
    File.join(daemon_home(path), '.daemon-alive')
  end

  ##
  # Path to the terminated file
  def terminated_file(path)
    File.join(daemon_home(path), '.daemon-terminated')
  end

  ##
  # When was a daemon last seen at +path+?
  def last_alive(path)
    f = alive_file(path)
    f = terminated_file(path) unless File.exist? f
    c = File.read(f)
    return nil if c.nil? || c.empty?
    Time.parse(c)
  rescue Errno::ENOENT
    return nil
  end
end
