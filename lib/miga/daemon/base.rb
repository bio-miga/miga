
require 'shellwords'

class MiGA::Daemon < MiGA::MiGA
end

module MiGA::Daemon::Base

  ##
  # Set/get #options, where +k+ is the Symbol of the option and +v+ is the value
  # (or nil to use as getter). Skips consistency tests if +force+. Returns new
  # value.
  def runopts(k, v = nil, force = false)
    k = k.to_sym
    unless v.nil?
      case k
      when :latency, :maxjobs, :ppn, :format_version
        v = v.to_i
      when :shutdown_when_done
        v = !!v
      when :nodelist
        if v =~ /^\$/
          vv = ENV[v.sub('$','')] or raise "Unset environment variable: #{v}"
          v = vv
        end
        say "Reading node list: #{v}"
        v = File.readlines(v).map(&:chomp)
      end
      raise "Daemon's #{k} cannot be set to zero." if !force and v == 0
      @runopts[k] = v
    end
    @runopts[k]
  end

  ##
  # Returns Integer indicating the number of seconds to sleep between checks
  def latency() runopts(:latency); end

  ##
  # Returns Integer indicating the maximum number of concurrent jobs to run
  def maxjobs() runopts(:maxjobs); end

  ##
  # Returns the path to the list of execution hostnames
  def nodelist() runopts(:nodelist); end

  ##
  # Returns Integer indicating the number of CPUs per job
  def ppn() runopts(:ppn); end

  ##
  # Returns Boolean indicating if the daemon should shutdown when processing is
  # complete
  def shutdown_when_done?() !!runopts(:shutdown_when_done); end

end

