# @package MiGA
# @license Artistic-2.0

require 'miga/version'
require 'miga/json'
require 'miga/common/base'
require 'miga/common/path'
require 'miga/common/format'

##
# Generic class used to handle system-wide information and methods, and parent
# of all other MiGA::* classes.
class MiGA::MiGA

  include MiGA::Common
  
  extend MiGA::Common::Path
  extend MiGA::Common::Format
  
  ENV['MIGA_HOME'] ||= ENV['HOME']

  ##
  # Has MiGA been initialized?
  def self.initialized?
    File.exist?(File.expand_path('.miga_rc', ENV['MIGA_HOME'])) and
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
  # If the first parameter is +IO+, the output is sent there,
  # otherwise it's sent to +$stderr+
  def say(*par)
    io = par.first.is_a?(IO) ? par.shift : $stderr
    io.puts(*par.map { |i| "[#{Time.now}] #{i}" })
  end

end

