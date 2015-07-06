#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jul-05-2015
#

module MiGA
   class Result
      # Class
      def self.exist? path
	 !!(File.size? path)
      end
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
	 json = JSON.pretty_generate self.data
	 ofh = File.open(self.path, 'w')
	 ofh.puts json
	 ofh.close
	 self.load
      end
      def load
	 json = File.read self.path
	 @data = JSON.parse(json, {:symbolize_names=>true})
	 @results = self.data[:results].map{ |rs| Result.new rs }
      end
      def remove!
	 self.each_file { |file| File.unlink_r(self.dir + file) if File.exist? self.dir + file }
	 File.unlink self.path
      end
      def each_file(&blk)
	 self.data[:files] = {} if self.data[:files].nil?
	 self.data[:files].each do |k,files|
	    files = [files] unless files.kind_of? Array
	    files.each{ |file| blk.call(file) }
	 end
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

