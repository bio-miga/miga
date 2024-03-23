# frozen_string_literal: true

require 'miga/result/dates'
require 'miga/result/source'
require 'miga/result/stats'
require 'miga/result/versions'

##
# The result from a task run. It can be project-wide or dataset-specific.
class MiGA::Result < MiGA::MiGA
  include MiGA::Result::Dates
  include MiGA::Result::Source
  include MiGA::Result::Stats
  include MiGA::Result::Versions

  # Class-level
  class << self
    ##
    # Check if the result described by the JSON in +path+ already exists
    def exist?(path)
      File.exist? path
    end

    ##
    # Load the result described by the JSON in +path+.
    # Returns MiGA::Result if it already exists, nil otherwise.
    def load(path)
      return nil unless MiGA::Result.exist? path

      MiGA::Result.new(path)
    end

    ##
    # Check if +path+ describes a result and otherwise create
    # it using the passed block. If +force+, ignore existing
    # JSON in +path+ if any, but it can rescue the versions 
    # field from the old one if it exists and the new one doesn't
    # contain such field.
    def create(path, force = false)
      # Deal with old results first
      r_old = load(path)
      return r_old if r_old && !force

      # Create the new result using the block passed
      FileUtils.rm(path) if r_old
      yield

      # Load and return
      load(path).tap do |r_new|
        # Rescue versions and start (if any and if necessary)
        if r_old
          %i[versions started].each { |i| r_new[i] ||= r_old[i] }
          r_new[:versions] = (r_old[:versions] || {}).merge(r_new[:versions])
        end
      end
    end
  end

  # Instance-level

  ##
  # Hash with the result metadata
  attr_reader :data

  ##
  # Load or create the MiGA::Result described by the JSON file +path+
  def initialize(path)
    @path = File.absolute_path(path)
    MiGA::Result.exist?(@path) ? load : create
  end

  ##
  # Is the result clean? Returns Boolean
  def clean?
    !!self[:clean]
  end

  ##
  # Register the result as cleaned, returns self
  def clean!
    self[:clean] = true
    self
  end

  ##
  # Is the result marked to be recalculated? Returns Boolean
  def recalculate?
    !!self[:recalculate]
  end

  ##
  # Mark the result to be recalculated, returns self
  def recalculate!(reason = nil)
    self[:recalculate] = true
    self[:recalculate_why] = reason
    self[:recalculate_when] = Time.now.to_s
    self
  end

  ##
  # Path to the standard files of the result. +which+ must be one of:
  # - :json (default) : JSON file describing the result.
  # - :start : File with the date when the processing started.
  # - :done : File with the date when the processing ended.
  def path(which = :json)
    case which.to_sym
    when :json
      @path
    when :start
      @path.sub(/\.json$/, '.start')
    when :done
      @path.sub(/\.json$/, '.done')
    end
  end

  ##
  # Directory containing the result; by default an absolute path, if
  # +relative+ is true returns the path relative to the parent project
  def dir(relative = false)
    relative ? relative_dir : File.dirname(path)
  end

  ##
  # Absolute path to the file(s) defined by symbol +k+, or relative
  # path if +relative+ is true
  def file_path(k, relative = false)
    k = k.to_sym
    f = self[:files].nil? ? nil : self[:files][k]
    return nil if f.nil?
    return File.join(dir(relative), f) unless f.is_a? Array

    f.map { |fi| File.join(dir(relative), fi) }
  end

  ##
  # Entry with symbol +k+
  def [](k)
    data[k.to_sym]
  end

  ##
  # Adds value +v+ to entry with symbol +k+
  def []=(k, v)
    data[k.to_sym] = v
  end

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
  # #add_file for each key-value pair in the +files+ Hash
  def add_files(files)
    files.each { |k, v| add_file(k, v) }
  end

  ##
  # Initialize and #save empty result
  def create
    @data = {
      created: Time.now.to_s,
      stats: {}, files: {},
      versions: { 'MiGA' => MiGA::VERSION.join('.') }
    }
    save
  end

  ##
  # Save the result persistently (in the JSON file #path)
  def save
    @data[:updated] = Time.now.to_s
    s = path(:start)
    if File.exist? s
      @data[:started] = File.read(s).chomp
      File.unlink s
    end
    MiGA::Json.generate(data, path)
    load
  end

  ##
  # Load (or reload) result data in the JSON file #path
  def load
    @data = MiGA::Json.parse(path)
    @data[:files] ||= {}
  end

  ##
  # Remove result, including all associated files
  def remove!
    each_file { |file| FileUtils.rm_rf(File.join(dir, file)) }
    unlink
  end

  # Unlink result by removing the .done and .start timestamps and the
  # .json descriptor, but don't remove any other associated files
  def unlink
    %i[start done json].each do |i|
      f = path(i) and File.exist?(f) and File.unlink(f)
    end
  end

  ##
  # Iterate +blk+ for each registered file. Depending on the number of
  # arguments of +blk+ (arity), it's called as:
  # - blk[file_rel]
  # - blk[file_sym, file_rel]
  # - blk[file_sym, file_rel, file_abs]
  # Note that multiple files may have the same symbol (file_sym), since
  # arrays of files are supported.
  def each_file(&blk)
    return to_enum(:each_file) unless block_given?

    @data[:files] ||= {}
    self[:files].each do |k, files|
      files = [files] unless files.is_a? Array
      files.each do |file|
        case blk.arity
        when 1 then blk.call(file)
        when 2 then blk.call(k, file)
        when 3 then blk.call(k, file, File.expand_path(file, dir))
        else
          raise "Wrong number of arguments: #{blk.arity} for 1..3"
        end
      end
    end
  end
end
