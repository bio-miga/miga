#
# @package EGR (codename)
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Dec-2-2014
#

require 'json'

module EGR
   class Result
      # Class
      def self.exist?(path) File.exist? path end
      def self.load path
	 return nil unless Result.exist? path
	 Result.new path
      end
      # Instance
      attr_reader :path, :data, :results
      def initialize(path)
	 @path = path
	 if Result.exist? path
	    self.load
	 else
	    self.create
	 end
      end
      def create
	 @data = {:created=>Time.now.to_s, :results=>[], :stats=>{}, :files=>{}}
	 self.save
      end
      def save
	 self.data[:updated] = Time.now.to_s
	 ofh = File.open(self.path, 'w')
	 ofh.puts self.data.to_json
	 ofh.close
	 self.load
      end
      def load
	 @data = JSON.parse(File.read(self.path), {:symbolize_names=>true})
	 @results = self.data[:results].map{ |rs| Result.new rs }
      end
      def add_result(result)
         self.data[:results] << result.path
	 self.save
      end
   end
end

