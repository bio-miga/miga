# @package MiGA
# @license Artistic-2.0

require "miga/version"
require "json"
require "tempfile"

##
# Generic class used to handle system-wide information and methods, and parent
# of all other MiGA::* classes.
class MiGA::MiGA
  
  ENV["MIGA_HOME"] ||= ENV["HOME"]

  ##
  # Root path to MiGA (as estimated from the location of the current file).
  def self.root_path ; File.expand_path("../../..", __FILE__) ; end

  ##
  # Should debugging information be reported?
  @@DEBUG = false

  ##
  # Should the trace of debugging information be reported?
  @@DEBUG_TRACE = false

  ##
  # Turn on debugging.
  def self.DEBUG_ON() @@DEBUG=true end

  ##
  # Turn off debugging.
  def self.DEBUG_OFF() @@DEBUG=false end

  ##
  # Turn on debug tracing (and debugging).
  def self.DEBUG_TRACE_ON
    @@DEBUG_TRACE=true
    self.DEBUG_ON
  end

  ##
  # Turn off debug tracing (but not debugging).
  def self.DEBUG_TRACE_OFF
    @@DEBUG_TRACE=false
  end

  ##
  # Send debug message.
  def self.DEBUG *args
    $stderr.puts(*args) if @@DEBUG
    $stderr.puts caller.map{|v| v.gsub(/^/,"    ")}.join("\n") if
      @@DEBUG_TRACE
  end

  ##
  # Has MiGA been initialized?
  def self.initialized?
    File.exist?(File.expand_path(".miga_rc", ENV["MIGA_HOME"])) and
      File.exist?(File.expand_path(".miga_daemon.json", ENV["MIGA_HOME"]))
  end

  ##
  # Tabulates an +values+, and Array of Arrays, all with the same number of
  # entries as +header+. Returns an Array of String, one per line.
  def self.tabulate(header, values)
    fields = [header.map{ |h| h.to_s }]
    fields << fields.first.map{ |h| h.gsub(/\S/, "-") }
    fields += values.map{ |row| row.map{ |cell| cell.nil? ? "?" : cell.to_s } }
    clen = fields.map{ |row|
      row.map{ |cell| cell.length } }.transpose.map{ |col| col.max }
    fields.map do |row|
      (0 .. clen.size-1).map do |col_n|
        col_n==0 ? row[col_n].rjust(clen[col_n]) : row[col_n].ljust(clen[col_n])
      end.join("  ")
    end
  end

  ##
  # Cleans a FastA file in place.
  def self.clean_fasta_file(file)
    tmp = Tempfile.new("MiGA")
    begin
      File.open(file, "r") do |fh|
        buffer = ""
        fh.each_line do |ln|
          ln.chomp!
          if ln =~ /^>\s*(\S+)(.*)/
            (id, df) = [$1, $2]
            tmp.print buffer.wrap_width(80)
            buffer = ""
            tmp.puts ">#{id.gsub(/[^A-Za-z0-9_\|\.]/, "_")}#{df}"
          else
            buffer += ln.gsub(/[^A-Za-z\.\-]/, "")
          end
        end
        tmp.print buffer.wrap_width(80)
      end
      tmp.close
      FileUtils.cp(tmp.path, file)
    ensure
      tmp.close
      tmp.unlink
    end
  end


  ##
  # Check if the result files exist with +base+ name (String) followed by the
  # +ext+ values (Array of String).
  def result_files_exist?(base, ext)
    ext = [ext] unless ext.kind_of? Array
    ext.all? do |f|
      File.exist?(base + f) or File.exist?(base + f + ".gz")
    end
  end

end

##
# MiGA extensions to the File class.
class File

  ##
  # Method to transfer a file from +old_name+ to +new_name+, using a +method+
  # that can be one of :symlink for File#symlink, :hardlink for File#link, or
  # :copy for FileUtils#cp_r.
  def self.generic_transfer(old_name, new_name, method)
    return nil if exist? new_name
    case method
    when :symlink
      File.symlink(old_name, new_name)
    when :hardlink
      File.link(old_name, new_name)
    when :copy
      FileUtils.cp_r(old_name, new_name)
    else
      raise "Unknown transfer method: #{method}."
    end
  end
  
end

##
# MiGA extensions to the String class.
class String
  
  ##
  # Replace any character not allowed in a MiGA name for underscore (_). This
  # results in a MiGA-compliant name EXCEPT for empty strings, that results in
  # empty strings.
  def miga_name ; gsub(/[^A-Za-z0-9_]/, "_") ; end

  ##
  # Is the string a MiGA-compliant name?
  def miga_name? ; not(self !~ /^[A-Za-z0-9_]+$/) ; end

  ##
  # Replace underscores by spaces.
  def unmiga_name ; tr("_", " ") ; end
  
  ##
  # Wraps the string with fixed Integer +width+.
  def wrap_width(width) ; gsub(/([^\n\r]{1,#{width}})/,"\\1\n") ; end

end
