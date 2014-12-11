#
# @package EGR (codename)
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Dec-2-2014
#

require 'JSON'

module EGR
   class Metadata
      # Class
      def self.exist?(path) File.exist? path end
      def self.load path
	 return nil unless Metadata.exist? path
	 Metadata.new path
      end
      # Instance
      attr_reader :path, :data
      def initialize(path, defaults={})
	 @path = path
	 @data = defaults
	 self.create unless File.exist? path
	 self.load
      end
      def create
         @data[:created] = Time.now.to_s
	 self.save
      end
      def save
         self.data[:updated] = Time.now.to_s
	 ofh = File.open(self.path, 'w')
	 ofh.puts self.data.to_json
	 ofh.close
      end
      def load
	 @data = JSON.parse(File.read(self.path), {:symbolize_names=>true})
	 @data[:type] = @data[:type].to_sym unless @data[:type].nil?
      end
      def [](k) self.data[k] end
      def []=(k,v) self.data[k]=v end
   end
end

