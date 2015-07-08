#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jul-08-2015
#

require 'date'
require 'json'
require 'fileutils'
require 'miga/project'
require 'miga/taxonomy'

module MiGA
   VERSION = [0.1, 1, 7]
   VERSION_NAME = "crosshatching"
   VERSION_DATE = Date.new(2015, 7, 8)
   CITATION = "Rodriguez-R et al, in preparation. Microbial Genomes Atlas: Standardizing genomic and metagenomic analyses for Archaea and Bacteria."
   class MiGA
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
	 $stderr.puts caller.map{|v| v.gsub(/^/,"    ")}.join("\n") if @@DEBUG_TRACE
      end
      def self.VERSION ; VERSION[0] ; end
      def self.LONG_VERSION
	 "MiGA " + VERSION.join(".") + " - " + VERSION_NAME + " - " + VERSION_DATE.to_s
      end
      def self.CITATION ; CITATION ; end
   end
end

class File
   def self.unlink_r(path)
      if Dir.exists? path
	 Dir.entries.reject{|f| f =~ /^\.\.?$/}.each{|f| File.unlink_r f} unless File.symlink? path
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
   def miga_name ; gsub /[^A-Za-z0-9_]/, "_" ; end
   def unmiga_name ; gsub /_/, " " ; end
end

