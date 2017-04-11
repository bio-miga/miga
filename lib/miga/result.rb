# @package MiGA
# @license Artistic-2.0

##
# The result from a task run. It can be project-wide or dataset-specific.
class MiGA::Result < MiGA::MiGA
  
  # Class-level
  
  ##
  # Check if the result described by the JSON in +path+ already exists.
  def self.exist?(path) File.exist? path end

  ##
  # Load the result described by the JSON in +path+. Returns MiGA::Result if it
  # already exists, nil otherwise.
  def self.load(path)
    return nil unless MiGA::Result.exist? path
    MiGA::Result.new(path)
  end

  # Instance-level

  ##
  # Path to the JSON file describing the result.
  attr_reader :path
  
  ##
  # Hash with the result metadata.
  attr_reader :data

  ##
  # Array of MiGA::Result objects nested within the result (if any).
  attr_reader :results
  
  ##
  # Load or create the MiGA::Result described by the JSON file +path+.
  def initialize(path)
    @path = path
    MiGA::Result.exist?(path) ? self.load : create
  end
  
  ##
  # Is the result clean? Returns Boolean.
  def clean? ; !! self[:clean] ; end

  ##
  # Register the result as cleaned.
  def clean! ; self[:clean] = true ; end

  ##
  # Directory containing the result.
  def dir
    File.dirname(path)
  end

  ##
  # Absolute path to the file(s) defined by symbol +k+.
  def file_path(k)
    k = k.to_sym
    f = self[:files].nil? ? nil : self[:files][k]
    return nil if f.nil?
    return File.expand_path(f, dir) unless f.is_a? Array
    f.map{ |fi| File.expand_path(fi, dir) }
  end

  ##
  # Entry with symbol +k+. 
  def [](k) data[k.to_sym] ; end

  ##
  # Adds value +v+ to entry with symbol +k+.
  def []=(k,v) data[k.to_sym]=v ; end

  ##
  # Register +file+ (path relative to #dir) with the symbol +k+. If the file
  # doesn't exist but the .gz extension does, the gzipped file is registered
  # instead. If neither exists, nothing is registered.
  def add_file(k, file)
    k = k.to_sym
    @data[:files] ||= {}
    @data[:files][k] = file if File.exist? File.expand_path(file, dir)
    @data[:files][k] = "#{file}.gz" if
      File.exist? File.expand_path("#{file}.gz", dir)
  end

  ##
  # #add_file for each key-value pair in the +files+ Hash.
  def add_files(files)
    files.each { |k, v| add_file(k, v) }
  end

  ##
  # Initialize and #save empty result.
  def create
    @data = {:created=>Time.now.to_s, :results=>[], :stats=>{}, :files=>{}}
    save
  end

  ##
  # Save the result persistently (in the JSON file #path).
  def save
    @data[:updated] = Time.now.to_s
    json = JSON.pretty_generate data
    ofh = File.open(path, "w")
    ofh.puts json
    ofh.close
    self.load
  end

  ##
  # Load (or reload) result data in the JSON file #path.
  def load
    json = File.read(path)
    @data = JSON.parse(json, {:symbolize_names=>true})
    @data[:files] ||= {}
    @results = self[:results].map{ |rs| MiGA::Result.new rs }
  end

  ##
  # Remove result, including all associated files.
  def remove!
    each_file do |file|
      f = File.expand_path(file, dir)
      FileUtils.rm_rf(f) if File.exist? f
    end
    %w(.start .done).each do |ext|
      f = path.sub(/\.json$/, ext)
      File.unlink f if File.exist? f
    end
    File.unlink path
  end

  ##
  # Iterate +blk+ for each registered file. If +blk+ calls for one argument, the
  # relative path to the file is passed. If it calls for two arguments, the
  # symbol describing the file is passed first and the path second. Note that
  # multiple files may have the same symbol, since arrays of files are
  # supported.
  def each_file(&blk)
    @data[:files] ||= {}
    self[:files].each do |k,files|
      files = [files] unless files.kind_of? Array
      files.each do |file|
        if blk.arity==1
          blk.call(file)
        elsif blk.arity==2
          blk.call(k, file)
        else
          raise "Wrong number of arguments: #{blk.arity} for one or two"
        end
      end
    end
  end

  ##
  # Add the MiGA::Result +result+ as part of the current result.
  def add_result(result)
    @data[:results] << result.path
    save
  end
  
end
