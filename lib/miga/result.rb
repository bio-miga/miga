#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Mar-12-2015
#

require 'json'

module MiGA
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
      def dir
	 File.dirname(self.path)
      end
      def create
	 @data = {:created=>Time.now.to_s, :results=>[], :stats=>{}, :files=>{}}
	 self.save
      end
      def save
	 self.data[:updated] = Time.now.to_s
	 ofh = File.open(self.path, 'w')
	 ofh.puts JSON.pretty_generate(self.data)
	 ofh.close
	 self.load
      end
      def load
	 @data = JSON.parse(File.read(self.path), {:symbolize_names=>true})
	 @results = self.data[:results].map{ |rs| Result.new rs }
      end
      def remove!
	 self.data[:files] = {} if self.data[:files].nil?
	 self.data[:files].each do |k,files|
	    files = [files] unless file.kind_of? Array
	    files.each{|file| File.unlink_r(self.dir + file)}
	 end
	 File.unlink self.path
      end
      def add_result(result)
         self.data[:results] << result.path
	 self.save
      end
      def file_path(file)
	 f = self.data[:files][file.to_sym]
	 return nil if f.nil?
	 return self.path + '/' + f unless f.is_a?(Array)
	 f.map{ |i| self.path + '/' + i }
      end
   end
end

