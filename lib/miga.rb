#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jun-16-2015
#

require 'date'
require 'json'
require 'fileutils'
require 'miga/project'
require 'miga/taxonomy'

module MiGA
   VERSION = [0.1, 1, 5]
   VERSION_NAME = "crosshatching"
   VERSION_DATE = Date.new(2015, 6, 16)
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
      def self.VERSION() VERSION[0] end
      def self.LONG_VERSION
	 "MiGA " + VERSION.join(".") + " - " + VERSION_NAME + " - " + VERSION_DATE.to_s
      end
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
end

class String
   def miga_name
      self.gsub /[^A-Za-z0-9_]/, "_"
   end
end

