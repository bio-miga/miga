#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update May-27-2015
#

require 'date'
require 'json'
require 'fileutils'
require 'miga/project'
require 'miga/taxonomy'

module MiGA
   VERSION = [0.1, 1, 1]
   VERSION_NAME = "crosshatching"
   VERSION_DATE = Date.new(2015, 06, 05)
end

class File
   def unlink_r(path)
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

