#
# @package MiGA
# @author  Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update  Dec-19-2015
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
	 File.dirname(path)
      end
      def file_path(k)
	 k = k.to_sym
	 return nil if self[:files].nil? or self[:files][k].nil?
	 return File.expand_path(self[:files][k], dir) unless
	    self[:files][k].is_a? Array
         self[:files][k].map{ |f| File.expand_path(f, dir) }
      end
      def [](k) data[k.to_sym] ; end
      def add_file(k, file)
         k = k.to_sym
	 self.data[:files] ||= {}
	 self.data[:files][k] = file if
	    File.exist? File.expand_path(file, dir)
	 self.data[:files][k] = file + ".gz" if
	    File.exist? File.expand_path(file + ".gz", dir)
      end
      def create
	 @data = {:created=>Time.now.to_s, :results=>[], :stats=>{}, :files=>{}}
	 self.save
      end
      def save
	 self.data[:updated] = Time.now.to_s
	 json = JSON.pretty_generate data
	 ofh = File.open(path, "w")
	 ofh.puts json
	 ofh.close
	 self.load
      end
      def load
	 json = File.read path
	 @data = JSON.parse(json, {:symbolize_names=>true})
	 @results = self[:results].map{ |rs| Result.new rs }
      end
      def remove!
	 each_file do |file|
	    f = File.expand_path(file, dir)
	    File.unlink_r(f) if File.exist? f
	 end
	 %w(.start .done).each do |ext|
	    f = path.sub(/\.json$/, ext)
	    File.unlink f if File.exist? f
	 end
	 File.unlink path
      end
      def each_file(&blk)
	 self.data[:files] = {} if self.data[:files].nil?
	 self.data[:files].each do |k,files|
	    files = [files] unless files.kind_of? Array
	    files.each do |file|
	       if blk.arity==1
		  blk.call file
	       elsif blk.arity==2
		  blk.call k, file
	       else
		  raise "Wrong number of arguments: #{blk.arity} for one or two"
	       end
	    end
	 end
      end
      def add_result(result)
         self.data[:results] << result.path
	 self.save
      end
      def file_path(file)
	 f = self.data[:files][file.to_sym]
	 return nil if f.nil?
	 return File.dirname(self.path) + "/" + f unless f.is_a?(Array)
	 f.map{ |i| File.dirname(self.path) + "/" + i }
      end
   end
end

