# frozen_string_literal: true

require 'zlib'
require 'stringio'
require 'miga/version'
require 'miga/json'
require 'miga/parallel'
require 'miga/common/base'
require 'miga/common/errors'
require 'miga/common/path'
require 'miga/common/format'
require 'miga/common/net'
require 'miga/common/system_call'

##
# Generic class used to handle system-wide information and methods, and parent
# of all other MiGA::* classes.
class MiGA::MiGA
  include MiGA::Common

  extend MiGA::Common::Path
  extend MiGA::Common::Format
  extend MiGA::Common::Net
  extend MiGA::Common::SystemCall

  ENV['MIGA_HOME'] ||= ENV['HOME']

  ##
  # Path to the +.miga_rc+ file
  def self.rc_path
    File.join(ENV['MIGA_HOME'], '.miga_rc')
  end

  ##
  # Has MiGA been initialized?
  def self.initialized?
    File.exist?(rc_path) &&
      File.exist?(File.join(ENV['MIGA_HOME'], '.miga_daemon.json'))
  end

  ##
  # Check if the result files exist with +base+ name (String) followed by the
  # +ext+ values (Array of String).
  def result_files_exist?(base, ext)
    ext = [ext] unless ext.is_a? Array
    MiGA::MiGA.DEBUG("Assserting files for result: #{ext}")
    ext.all? { |f| File.exist?(base + f) or File.exist?("#{base}#{f}.gz") }
  end

  ##
  # Print +par+ ensuring new line at the end.
  # Date/time-stamp each line.
  # If the first parameter is +IO+ or +StringIO+ the output is sent there,
  # otherwise it's sent to +$stderr+
  def say(*par)
    io = like_io?(par.first) ? par.shift : $stderr
    io.puts(*par.map { |i| "[#{Time.now}] #{i}" })
  end

  ##
  # Reports the advance of a task at +step+ (String), the +n+ out of +total+.
  # The advance is reported in powers of 1,024 if +bin+ is true, or powers of
  # 1,000 otherwise.
  # The report goes to $stderr iff --verbose
  def advance(step, n = 0, total = nil, bin = true)
    # Initialize advance timing
    @_advance_time ||= { last: nil, n: 0, avg: nil, total: total }
    if @_advance_time[:n] > n || total != @_advance_time[:total]
      @_advance_time[:last] = nil
      @_advance_time[:n] = 0
      @_advance_time[:avg]  = nil
      @_advance_time[:total] = total
    end

    # Estimate timing
    adv_n = n - @_advance_time[:n]
    if total.nil? || @_advance_time[:last].nil? || adv_n.negative?
      # Initial report
      @_advance_time[:last] = Time.now
      @_advance_time[:n] = n
    elsif adv_n > 0.001 * total
      # Advance report (if change > 0.1% change and time > 1 second)
      this_time = (Time.now - @_advance_time[:last]).to_f
      return if this_time < 1.0 && n < total

      this_avg = this_time / adv_n
      @_advance_time[:avg] ||= this_avg
      @_advance_time[:avg] = 0.9 * @_advance_time[:avg] + 0.1 * this_avg
      @_advance_time[:last] = Time.now
      @_advance_time[:n] = n
    else
      # Final report (if the last update was too small) or ignore update
      return if n < total
    end

    # Report
    adv =
      if total.nil?
        (n == 0 ? '' : num_suffix(n, bin))
      else
        vals = [100.0 * n / total, num_suffix(n, bin), num_suffix(total, bin)]
        ('%.1f%% (%s/%s)' % vals)
      end
    left =
      if @_advance_time[:avg].nil?
        ''
      else
        left_time = @_advance_time[:avg] * (total - n) / 60 # <- in minutes
        left_time   < 0.01 ? '' :
          left_time < 1    ? ('%.0fs left' % (left_time * 60))   :
          left_time > 1440 ? ('%.1fd left' % (left_time / 1440)) :
          left_time > 60   ? ('%.1fh left' % (left_time / 60))   :
          ('%.1fm left' % left_time)
      end
    $stderr.print("[%s] %s %s %-12s   \r" % [Time.now, step, adv, left])
  end

  ##
  # Return formatted number +n+ with the appropriate units as
  # powers of 1,000 (if +bin+ if false) or 1,024 (otherwise)
  def num_suffix(n, bin = false)
    p = ''
    { T: 4, G: 3, M: 2, K: 1 }.each do |k, x|
      v = (bin ? 1024 : 1e3)**x
      if n > v
        n = '%.1f' % (n.to_f / v)
        p = k
        break
      end
    end
    "#{n}#{p}"
  end

  def like_io?(obj)
    obj.is_a?(IO) || obj.is_a?(StringIO)
  end
end
