
require 'tempfile'
require 'zlib'

module MiGA::Common::Format
  ##
  # Tabulates an +values+, and Array of Arrays, all with the same number of
  # entries as +header+. Returns an Array of String, one per line.
  def tabulate(header, values, tabular=false)
    fields = [header.map(&:to_s)]
    fields << fields.first.map { |h| h.gsub(/\S/, '-') } unless tabular
    fields += values.map { |r| r.map { |cell| cell.nil? ? '?' : cell.to_s } }
    clen = tabular ? Array.new(header.size, 0) :
          fields.map { |r| r.map(&:length) }.transpose.map(&:max)
    fields.map do |r|
      (0 .. clen.size - 1).map do |col_n|
        col_n == 0 ? r[col_n].rjust(clen[col_n]) : r[col_n].ljust(clen[col_n])
      end.join(tabular ? "\t" : '  ')
    end
  end

  ##
  # Cleans a FastA file in place.
  def clean_fasta_file(file)
    tmp_fh = nil
    begin
      if file =~ /\.gz/
        tmp_path = Tempfile.new('MiGA.gz').tap(&:close).path
        tmp_fh = Zlib::GzipWriter.open(tmp_path)
        fh = Zlib::GzipReader.open(file)
      else
        tmp_fh = Tempfile.new('MiGA')
        tmp_path = tmp_fh.path
        fh = File.open(file, 'r')
      end
      buffer = ''
      fh.each_line do |ln|
        ln.chomp!
        if ln =~ /^>\s*(\S+)(.*)/
          (id, df) = [$1, $2]
          tmp_fh.print buffer.wrap_width(80)
          buffer = ''
          tmp_fh.puts ">#{id.gsub(/[^A-Za-z0-9_\|\.]/, '_')}#{df}"
        else
          buffer << ln.gsub(/[^A-Za-z\.\-]/, '')
        end
      end
      tmp_fh.print buffer.wrap_width(80)
      tmp_fh.close
      fh.close
      FileUtils.cp(tmp_path, file)
    ensure
      begin
        tmp_fh.close unless tmp_fh.nil?
        File.unlink(tmp_path) unless tmp_path.nil?
      rescue
      end
    end
  end

  ##
  # Calculates the average and standard deviation of the sequence lengths in
  # a FastA or FastQ file (supports gzipped files). The +format+ must be a
  # Symbol, one of +:fasta+ or +:fastq+. Additional estimations can be
  # controlled via the +opts+ Hash. Supported options include:
  # - +:n50+: If true, it also returns the N50 and the median (in bp).
  # - +gc+: If true, it also returns the G+C content (in %).
  def seqs_length(file, format, opts = {})
    fh = (file =~ /\.gz/) ? Zlib::GzipReader.open(file) : File.open(file, 'r')
    l = []
    gc = 0
    i = 0 # <- Zlib::GzipReader doesn't set $.
    fh.each_line do |ln|
      i += 1
      if (format == :fasta and ln =~ /^>/) or (format == :fastq and (i % 4)==1)
        l << 0
      elsif format == :fasta or (i % 4) == 2
        l[l.size-1] += ln.chomp.size
        gc += ln.scan(/[GCgc]/).count if opts[:gc]
      end
    end
    fh.close

    o = { n: l.size, tot: l.inject(:+) }
    o[:avg] = o[:tot].to_f / l.size
    o[:var] = l.map { |a| a**2 }.inject(:+).to_f / l.size - o[:avg]**2
    o[:sd]  = Math.sqrt o[:var]
    o[:gc]  = 100.0 * gc / o[:tot] if opts[:gc]
    if opts[:n50]
      l.sort!
      thr = o[:tot] / 2
      pos = 0
      l.each do |a|
        pos += a
        o[:n50] = a
        break if pos >= thr
      end
      o[:med] = o[:n].even? ?
            0.5 * l[o[:n] / 2 - 1, 2].inject(:+) : l[(o[:n] - 1) / 2]
    end
    o
  end
end

##
# MiGA extensions to the String class.
class String
  ##
  # Replace any character not allowed in a MiGA name for underscore (_). This
  # results in a MiGA-compliant name EXCEPT for empty strings, that results in
  # empty strings.
  def miga_name
    gsub(/[^A-Za-z0-9_]/, '_')
  end

  ##
  # Is the string a MiGA-compliant name?
  def miga_name?
    !(self !~ /^[A-Za-z0-9_]+$/)
  end

  ##
  # Replace underscores by spaces or dots (depending on context).
  def unmiga_name
    gsub(/_(str|sp|subsp|pv)__/, '_\\1._').tr('_', ' ')
  end

  ##
  # Wraps the string with fixed Integer +width+.
  def wrap_width(width)
    gsub(/([^\n\r]{1,#{width}})/, "\\1\n")
  end
end

