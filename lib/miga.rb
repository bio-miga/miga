#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Mar-12-2015
#

require 'miga/miga'

module MiGA
   VERSION = "0.0.1"
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


