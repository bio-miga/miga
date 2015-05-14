#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update May-14-2015
#

require 'json'
require 'fileutils'

module MiGA
   class Metadata
      # Class
      def self.exist?(path) File.size? path end
      def self.load path
	 return nil unless Metadata.exist? path
	 Metadata.new path
      end
      # Instance
      attr_reader :path, :data
      def initialize(path, defaults={})
	 @path = File.absolute_path(path)
	 @data = {}
	 defaults.each_pair{ |k,v| self[k]=v }
	 self.create unless File.size? path
	 self.load
      end
      def create
         @data[:created] = Time.now.to_s
	 self.save
      end
      def save
	 while File.exist? self.path + '.lock'
	    sleep(1)
	 end
	 FileUtils.touch self.path + '.lock'
         self.data[:updated] = Time.now.to_s
	 ofh = File.open(self.path + '.tmp', 'w')
	 ofh.puts JSON.pretty_generate(self.data)
	 ofh.close
	 File.rename self.path + '.tmp', self.path
	 File.unlink self.path + '.lock'
      end
      def load
	 while File.exist? self.path + '.lock'
	    sleep(1)
	 end
	 @data = JSON.parse(File.read(self.path), {:symbolize_names=>true})
	 @data[:type] = @data[:type].to_sym unless @data[:type].nil?
      end
      def remove!
	 File.unlink self.path
      end
      def [](k) self.data[k.to_sym] end
      def []=(k,v)
	 k = k.to_sym
	 # Protect the special field :name
	 v.gsub!(/[^A-Za-z0-9_]/,'_') if k==:name
	 # Register and return
	 self.data[k]=v
      end
   end
end

