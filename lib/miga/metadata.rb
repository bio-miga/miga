#
# @package MiGA
# @author Luis M. Rodriguez-R <lmrodriguezr at gmail dot com>
# @license artistic license 2.0
# @update Jun-08-2015
#

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
	 self.create unless File.size? self.path
	 self.load
      end
      def create
         @data[:created] = Time.now.to_s
	 self.save
      end
      def save
         self.data[:updated] = Time.now.to_s
	 json = JSON.pretty_generate(self.data)
	 sleeper = 0.0
	 while File.exist? self.path + ".lock"
	    sleeper += 0.1 if sleeper <= 10.0
	    sleep(sleeper.to_i)
	 end
	 FileUtils.touch self.path + ".lock"
	 ofh = File.open(self.path + ".tmp", "w")
	 ofh.puts json
	 ofh.close
	 raise "Lock-racing detected for #{self.path}." unless File.exist? self.path + ".tmp" and File.exist? self.path + ".lock"
	 File.rename self.path + ".tmp", self.path
	 File.unlink self.path + ".lock"
      end
      def load
	 sleeper = 0.0
	 while File.exist? self.path + ".lock"
	    sleeper += 0.1 if sleeper <= 10.0
	    sleep(sleeper.to_i)
	 end
	 @data = JSON.parse File.read(self.path), {:symbolize_names=>true, :create_additions=>true}
	 @data[:type] = @data[:type].to_sym unless @data[:type].nil?
      end
      def remove!
	 File.unlink self.path
      end
      def [](k) self.data[k.to_sym] end
      def []=(k,v)
	 k = k.to_sym
	 # Protect the special field :name
	 v.gsub!(/[^A-Za-z0-9_]/,"_") if k==:name
	 # Register and return
	 self.data[k]=v
      end
   end
end

