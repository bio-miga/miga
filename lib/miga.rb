#
# @package MiGA
# @author  Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
#

require "json"
require "fileutils"
require "miga/version"
require "miga/project"
require "miga/taxonomy"

class MiGA::MiGA
  
  @@DEBUG = false
  @@DEBUG_TRACE = false
  def self.DEBUG_ON() @@DEBUG=true end
  def self.DEBUG_OFF() @@DEBUG=false end
  def self.DEBUG_TRACE_ON
    @@DEBUG_TRACE=true
    self.DEBUG_ON
  end
  def self.DEBUG_TRACE_OFF
    @@DEBUG_TRACE=false
    self.DEBUG_OFF
  end
  def self.DEBUG *args
    $stderr.puts(*args) if @@DEBUG
    $stderr.puts caller.map{|v| v.gsub(/^/,"    ")}.join("\n") if
      @@DEBUG_TRACE
  end

  def result_files_exist?(base, ext)                                                                                                                    
    ext.all? do |f|
      File.exist?(base + f) or File.exist?(base + f + ".gz")
    end
  end
  
end

class File
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

class String
  def miga_name ; gsub(/[^A-Za-z0-9_]/, "_") ; end
  def miga_name? ; not(self !~ /^[A-Za-z0-9_]+$/) ; end
  def unmiga_name ; gsub(/_/, " ") ; end
end

