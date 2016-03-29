# @package MiGA
# @license artistic license 2.0

require "json"
require "fileutils"
require "miga/version"
require "miga/project"
require "miga/taxonomy"

##
# Generic class used to handle system-wide information and methods, and parent
# of all other MiGA::* classes.
class MiGA::MiGA
  
  ##
  # Should debugging information be reported?
  @@DEBUG = false

  ##
  # Should the trace of debugging information be reported?
  @@DEBUG_TRACE = false

  ##
  # Turn on debugging.
  def self.DEBUG_ON() @@DEBUG=true end

  ##
  # Turn off debugging.
  def self.DEBUG_OFF() @@DEBUG=false end

  ##
  # Turn on debug tracing (and debugging).
  def self.DEBUG_TRACE_ON
    @@DEBUG_TRACE=true
    self.DEBUG_ON
  end

  ##
  # Turn off debug tracing (and debugging).
  def self.DEBUG_TRACE_OFF
    @@DEBUG_TRACE=false
    self.DEBUG_OFF
  end

  ##
  # Send debug message.
  def self.DEBUG *args
    $stderr.puts(*args) if @@DEBUG
    $stderr.puts caller.map{|v| v.gsub(/^/,"    ")}.join("\n") if
      @@DEBUG_TRACE
  end

  ##
  # Check if the result files exist with +base+ name (String) followed by the
  # +ext+ values (Array of String).
  def result_files_exist?(base, ext)
    ext = [ext] unless ext.kind_of? Array
    ext.all? do |f|
      File.exist?(base + f) or File.exist?(base + f + ".gz")
    end
  end
  
end

##
# MiGA extensions to the File class.
class File

  ##
  # FIXME This extension should be removed and replaced with FileUtils.rm_rf
  def self.unlink_r(path)
    if Dir.exists? path
      unless File.symlink? path
        Dir.entries(path).reject{|f| f =~ /^\.\.?$/}.each do |f|
          File.unlink_r path + "/" + f
        end
      end
      Dir.unlink path
    elsif File.exists? path
      File.unlink path
    else
      raise "Cannot find file: #{path}"
    end
  end
  
  ##
  # Method to transfer a file from +old_name+ to +new_name+, using a +method+
  # that can be one of :symlink for File#symlink, :hardlink for File#link, or
  # :copy for FileUtils#cp_r.
  def self.generic_transfer(old_name, new_name, method)
    return nil if exist? new_name
    case method
    when :symlink
      File.symlink(old_name, new_name)
    when :hardlink
      File.link(old_name, new_name)
    when :copy
      FileUtils.cp_r(old_name, new_name)
    else
      raise "Unknown transfer method: #{method}."
    end
  end

end

##
# MiGA extensions to the String class.
class String
  
  ##
  # Replace any character not allowed in a MiGA name for underscore (_). This
  # results in a MiGA-compliant name EXCEPT for empty strings, that results in
  # empty strings.
  def miga_name ; gsub(/[^A-Za-z0-9_]/, "_") ; end

  ##
  # Is the string a MiGA-compliant name?
  def miga_name? ; not(self !~ /^[A-Za-z0-9_]+$/) ; end

  ##
  # Replace underscores by spaces.
  def unmiga_name ; gsub(/_/, " ") ; end
  
end
