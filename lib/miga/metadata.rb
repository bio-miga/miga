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
  # Hash (Integer) of the last saved data Hash (object)
  attr_reader :saved_hash

  ##
  # Initiate a MiGA::Metadata object with description in +path+.
  # It will create it if it doesn't exist.
  def initialize(path, defaults = {})
    @data = nil
    @path = File.absolute_path(path)
    @saved_hash = nil
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
    return if !saved_hash.nil? && saved_hash == data.hash

    MiGA::MiGA.DEBUG "Metadata.save #{path}"
    path_tmp = "#{path}.tmp"
    self[:updated] = Time.now.to_s
    @saved_hash = data.hash
    json = to_json
    wait_for_lock
    FileUtils.touch(lock_file)
    File.open(path_tmp, 'w') { |ofh| ofh.puts json }

    unless File.exist?(path_tmp) && File.exist?(lock_file)
      raise "Lock-racing detected for #{path}"
    end

    File.rename(path_tmp, path)
    File.unlink(lock_file)
  end

  ##
  # Force +save+ even if nothing has changed since the last save
  # or load. However, it doesn't save if +:never_save+ is true.
  def save!
    @saved_hash = nil
    save
  end

  ##
  # (Re-)load metadata stored in #path
  def load
    wait_for_lock
    tmp = MiGA::Json.parse(path, additions: true)
    @data = {}
    tmp.each { |k, v| self[k] = v }
    @saved_hash = data.hash
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
    if k.to_s =~ /(.+):(.+)/
      data[$1.to_sym]&.fetch($2)
    else
      data[k.to_sym]
    end
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

  private

  ##
  # Wait for the lock to go away
  def wait_for_lock
    sleeper = 0.0
    slept = 0.0
    while File.exist?(lock_file)
      MiGA::MiGA.DEBUG "Waiting for lock: #{lock_file}"
      sleeper += 0.1 if sleeper <= 10.0
      sleep(sleeper)
      slept += sleeper
      raise "Lock detected for over 10 minutes: #{lock_file}" if slept > 600
    end
  end
end
