# @package MiGA
# @license Artistic-2.0

##
# Metadata associated to objects like MiGA::Project, MiGA::Dataset, and
# MiGA::Result.
class MiGA::Metadata < MiGA::MiGA
  # Class-level

  ##
  # Does the metadata described in +path+ already exist?
  def self.exist?(path) File.exist? path end

  ##
  # Load the metadata described in +path+ and return MiGA::Metadata if it
  # exists, or nil otherwise.
  def self.load(path)
    return nil unless Metadata.exist? path

    MiGA::Metadata.new(path)
  end

  # Instance-level

  ##
  # Path to the JSON file describing the metadata
  attr_reader :path

  ##
  # Initiate a MiGA::Metadata object with description in +path+.
  # It will create it if it doesn't exist.
  def initialize(path, defaults = {})
    @data = nil
    @path = File.absolute_path(path)
    unless File.exist? path
      @data = {}
      defaults.each { |k, v| self[k] = v }
      create
    end
  end

  ##
  # Parsed data as a Hash
  def data
    self.load if @data.nil?
    @data
  end

  ##
  # Reset :created field and save the current data
  def create
    self[:created] = Time.now.to_s
    save
  end

  ##
  # Save the metadata into #path
  def save
    return if self[:never_save]

    MiGA.DEBUG "Metadata.save #{path}"
    self[:updated] = Time.now.to_s
    json = to_json
    sleeper = 0.0
    slept = 0
    while File.exist?(lock_file)
      MiGA::MiGA.DEBUG "Waiting for lock: #{lock_file}"
      sleeper += 0.1 if sleeper <= 10.0
      sleep(sleeper.to_i)
      slept += sleeper.to_i
      raise "Lock detected for over 10 minutes: #{lock_file}" if slept > 600
    end
    FileUtils.touch lock_file
    ofh = File.open("#{path}.tmp", 'w')
    ofh.puts json
    ofh.close
    raise "Lock-racing detected for #{path}" unless
      File.exist?("#{path}.tmp") and File.exist?(lock_file)

    File.rename("#{path}.tmp", path)
    File.unlink(lock_file)
  end

  ##
  # (Re-)load metadata stored in #path
  def load
    sleeper = 0.0
    while File.exist? lock_file
      sleeper += 0.1 if sleeper <= 10.0
      sleep(sleeper.to_i)
    end
    tmp = MiGA::Json.parse(path, additions: true)
    @data = {}
    tmp.each { |k, v| self[k] = v }
  end

  ##
  # Delete file at #path
  def remove!
    MiGA.DEBUG "Metadata.remove! #{path}"
    File.unlink(path)
    nil
  end

  ##
  # Lock file for the metadata
  def lock_file
    "#{path}.lock"
  end

  ##
  # Return the value of +k+ in #data
  def [](k)
    data[k.to_sym]
  end

  ##
  # Set the value of +k+ to +v+
  def []=(k, v)
    self.load if @data.nil?
    k = k.to_sym
    return @data.delete(k) if v.nil?

    case k
    when :name
      # Protect the special field :name
      v = v.miga_name
    when :type
      # Symbolize the special field :type
      v = v.to_sym if k == :type
    end

    @data[k] = v
  end

  ##
  # Iterate +blk+ for each data with 2 arguments: key and value
  def each(&blk)
    data.each { |k, v| blk.call(k, v) }
  end

  ##
  # Time of last update
  def updated
    Time.parse(self[:updated]) unless self[:updated].nil?
  end

  ##
  # Time of creation
  def created
    Time.parse(self[:created]) unless self[:created].nil?
  end

  ##
  # Show contents in JSON format as a String
  def to_json
    MiGA::Json.generate(data)
  end
end
