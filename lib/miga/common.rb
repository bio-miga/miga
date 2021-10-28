# @package MiGA
# @license Artistic-2.0

require 'miga/version'
require 'miga/json'
require 'miga/parallel'
require 'miga/common/base'
require 'miga/common/path'
require 'miga/common/format'
require 'miga/common/net'
require 'stringio'

##
# Generic class used to handle system-wide information and methods, and parent
# of all other MiGA::* classes.
class MiGA::MiGA
  include MiGA::Common

  extend MiGA::Common::Path
  extend MiGA::Common::Format
  extend MiGA::Common::Net

  ENV['MIGA_HOME'] ||= ENV['HOME']

  ##
  # Has MiGA been initialized?
  def self.initialized?
    File.exist?(File.expand_path('.miga_rc', ENV['MIGA_HOME'])) &&
      File.exist?(File.expand_path('.miga_daemon.json', ENV['MIGA_HOME']))
  end

  ##
  # Check if the result files exist with +base+ name (String) followed by the
  # +ext+ values (Array of String).
  def result_files_exist?(base, ext)
    ext = [ext] unless ext.is_a? Array
    ext.all? do |f|
      File.exist?(base + f) or File.exist?("#{base}#{f}.gz")
    end
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
    @_advance_time ||= { last: nil, n: 0, avg: nil }
    if @_advance_time[:n] > n
      @_advance_time[:last] = nil
      @_advance_time[:n] = 0
      @_advance_time[:avg]  = nil
    end

    # Estimate timing
    adv_n = n - @_advance_time[:n]
    if total.nil? || @_advance_time[:last].nil? || adv_n.negative?
      @_advance_time[:last] = Time.now
      @_advance_time[:n] = n
    elsif adv_n > 0.001 * total
      this_time = (Time.now - @_advance_time[:last]).to_f
      this_avg = this_time / adv_n
      @_advance_time[:avg] ||= this_avg
      @_advance_time[:avg] = 0.9 * @_advance_time[:avg] + 0.1 * this_avg
      @_advance_time[:last] = Time.now
      @_advance_time[:n] = n
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
        left_time < 0.01 ? '         ' :
          left_time < 1 ? ('%.0fs left' % (left_time * 60)) :
          left_time > 1440 ? ('%.1fd left' % (left_time / 1440)) :
          left_time > 60 ? ('%.1fh left' % (left_time / 60)) :
          ('%.1fm left' % left_time)
      end
    $stderr.print("[%s] %s %s %s    \r" % [Time.now, step, adv, left])
  end

  ##
  # Return formatted number +n+ with the appropriate units as
  # powers of 1,000 (if +bin+ if false) or 1,024 (otherwise)
  def num_suffix(n, bin = false)
    p = ''
    { T: 4, G: 3, M: 2, K: 1 }.each do |k, x|
      v = (bin ? 1024 : 1e3)**x
      if n > v
        n = '%.1f' % (n / v)
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
