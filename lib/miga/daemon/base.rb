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
      when :latency, :maxjobs, :ppn, :format_version, :verbosity
        v = v.to_i
        if !force && v == 0 && k != :verbosity
          raise "Daemon's #{k} cannot be set to zero"
        end
      when :shutdown_when_done, :show_log
        v = !!v
      when :nodelist
        if v =~ /^\$/
          vv = ENV[v.sub('$', '')] or raise "Unset environment variable: #{v}"
          v = vv
        end
        say "Reading node list: #{v}"
        v = File.readlines(v).map(&:chomp)
      end
      @runopts[k] = v
    end
    @runopts[k]
  end

  ##
  # Returns Integer indicating the number of seconds to sleep between checks
  def latency
    runopts(:latency)
  end

  ##
  # Returns Integer indicating the maximum number of concurrent jobs to run
  def maxjobs
    runopts(:maxjobs)
  end

  ##
  # Returns the path to the list of execution hostnames
  def nodelist
    runopts(:nodelist)
  end

  ##
  # Returns Integer indicating the number of CPUs per job
  def ppn
    runopts(:ppn)
  end

  ##
  # Returns Boolean indicating if the daemon should shutdown when processing is
  # complete
  def shutdown_when_done?
    !!runopts(:shutdown_when_done)
  end

  ##
  # Returns the level of verbosity for the daemon as an Integer, or 1 if unset.
  # Verbosity levels are:
  # 0: No output
  # 1: General daemon and job information
  # 2: Same, and indicate when each task is performed (even if nothing happens)
  # 3: Same, and indicate when each loop begins and ends
  def verbosity
    runopts(:verbosity) || 1
  end

  ##
  # Writing file handler (IO) to the log file
  def logfh
    return $stderr if show_log?

    @logfh ||= File.open(output_file, 'w')
  end

  ##
  # Display log instead of the progress summary
  def show_log!
    @show_log = true
  end

  ##
  # Display progress summary instead of the log
  def show_summary!
    @runopts[:show_log] = false
  end

  ##
  # Display log instead of the progress summary?
  def show_log?
    @runopts[:show_log] ||= false
  end
end
