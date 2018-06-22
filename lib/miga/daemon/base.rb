
require 'daemons'
require 'date'

class MiGA::Daemon < MiGA::MiGA
end

module MiGA::Daemon::Base

  ##
  # Set/get #options, where +k+ is the Symbol of the option and +v+ is the value
  # (or nil to use as getter). Skips consistency tests if +force+. Returns new
  # value.
  def runopts(k, v=nil, force=false)
    k = k.to_sym
    unless v.nil?
      if [:latency, :maxjobs, :ppn].include?(k)
        v = v.to_i
      elsif [:shutdown_when_done].include?(k)
        v = !!v
      end
      raise "Daemon's #{k} cannot be set to zero." if !force and v==0
      @runopts[k] = v
    end
    if k==:kill and v.nil?
      case @runopts[:type].to_s
      when 'bash' then return "kill -9 '%s'"
      when 'qsub' then return "qdel '%s'"
      else             return "canceljob '%s'"
      end
    end
    @runopts[k]
  end

  ##
  # Returns Integer indicating the number of seconds to sleep between checks.
  def latency() runopts(:latency); end

  ##
  # Returns Integer indicating the maximum number of concurrent jobs to run.
  def maxjobs() runopts(:maxjobs); end

  ##
  # Returns Integer indicating the number of CPUs per job.
  def ppn() runopts(:ppn); end

  ##
  # Returns Boolean indicating if the daemon should shutdown when processing is
  # complete.
  def shutdown_when_done?() !!runopts(:shutdown_when_done); end

  ##
  # Initializes the daemon with +opts+.
  def start(opts=[]) daemon('start', opts); end

  ##
  # Stops the daemon with +opts+.
  def stop(opts=[]) daemon('stop', opts); end

  ##
  # Restarts the daemon with +opts+.
  def restart(opts=[]) daemon('restart', opts); end

  ##
  # Returns the status of the daemon with +opts+.
  def status(opts=[]) daemon('status', opts); end

end

