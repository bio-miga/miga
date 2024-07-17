# frozen_string_literal: true

require 'tempfile'

##
# General formatting functions shared throughout MiGA.
module MiGA::Common::Format
  ##
  # Tabulates an +values+, and Array of Arrays, all with the same number of
  # entries as +header+. Returns an Array of String, one per line.
  def tabulate(header, values, tabular = false)
    fields = []
    fields << header.map(&:to_s) unless tabular && header.all?(&:nil?)
    fields << fields.first.map { |h| h.gsub(/\S/, '-') } unless tabular
    fields += values.map { |r| r.map { |cell| cell.nil? ? '?' : cell.to_s } }
    clen = tabular ? Array.new(header.size, 0) :
          fields.map { |r| r.map(&:length) }.transpose.map(&:max)
    fields.map do |r|
      (0..(clen.size - 1)).map do |col_n|
        col_n == 0 ? r[col_n].rjust(clen[col_n]) : r[col_n].ljust(clen[col_n])
      end.join(tabular ? "\t" : '  ')
    end
  end

  ##
  # Cleans a FastA file in place, removing all sequences shorter than
  # +min_len+
  def clean_fasta_file(file, min_len = 1)
    tmp_fh = nil
    tmp_path = nil
    begin
      if file =~ /\.gz/
        tmp_path = Tempfile.new('MiGA.gz').tap(&:close).path
        File.unlink tmp_path
        tmp_path += '.gz'
        tmp_fh = Zlib::GzipWriter.open(tmp_path, 9)
        fh = Zlib::GzipReader.open(file)
      else
        tmp_fh = Tempfile.new('MiGA')
        tmp_path = tmp_fh.path
        fh = File.open(file, 'r')
      end
      next_seq = ['', '']
      fh.each_line do |ln|
        ln.chomp!
        if ln =~ /^>\s*(\S+)(.*)/
          id, df = $1, $2
          if next_seq[1].length >= min_len
            tmp_fh.puts next_seq[0]
            tmp_fh.print next_seq[1].wrap_width(80)
          end
          next_seq = [">#{id.gsub(/[^A-Za-z0-9_\|\.]/, '_')}#{df}", '']
        else
          next_seq[1] += ln.gsub(/[^A-Za-z\.\-]/, '')
        end
      end
      if next_seq[1].length >= min_len
        tmp_fh.puts next_seq[0]
        tmp_fh.print next_seq[1].wrap_width(80)
      end
      tmp_fh.close
      fh.close
      FileUtils.mv(tmp_path, file)
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
  # - +:n50+: Include the N50 and the median (in bp)
  # - +:gc+: Include the G+C content (in %)
  # - +:x+: Include the undetermined bases content (in %)
  # - +:skew+: Include G-C and A-T sequence skew (in %; forces gc: true).
  #   See definition used here in DOI:10.1177/117693430700300006
  def seqs_length(file, format, opts = {})
    opts[:gc] = true if opts[:skew]
    fh = file =~ /\.gz/ ? Zlib::GzipReader.open(file) : File.open(file, 'r')
    l = []
    gc = 0
    xn = 0
    t  = 0
    c  = 0
    i  = 0 # <- Zlib::GzipReader doesn't set `$.`
    fh.each_line do |ln|
      i += 1
      if (format == :fasta and ln =~ /^>/) or
         (format == :fastq and (i % 4) == 1)
        l << 0
      elsif format == :fasta or (i % 4) == 2
        l[l.size - 1] += ln.chomp.size
        gc += ln.scan(/[GCgc]/).count if opts[:gc]
        xn += ln.scan(/[XNxn]/).count if opts[:x]
        if opts[:skew]
          t += ln.scan(/[Tt]/).count
          c += ln.scan(/[Cc]/).count
        end
      end
    end
    fh.close

    o = { n: l.size, tot: l.inject(0, :+), max: l.max }
    return o if o[:tot].zero?
    o[:avg] = o[:tot].to_f / l.size
    o[:var] = l.map { |a| a**2 }.inject(:+).to_f / l.size - o[:avg]**2
    o[:sd]  = Math.sqrt o[:var]
    o[:gc]  = 100.0 * gc / o[:tot] if opts[:gc]
    o[:x]   = 100.0 * xn / o[:tot] if opts[:x]
    if opts[:skew]
      at = o[:tot] - gc
      o[:at_skew] = 100.0 * (2 * t - at) / at
      o[:gc_skew] = 100.0 * (2 * c - gc) / gc
    end

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
            0.5 * l[o[:n] / 2 - 1, 2].inject(:+) :
            l[(o[:n] - 1) / 2]
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
  # Replace underscores by spaces or other symbols depending on context
  def unmiga_name
    gsub(/_(str|sp|subsp|pv)__/, '_\\1._')
      .gsub(/g_c_(content)/, 'G+C \\1')
      .gsub(/g_c_(skew)/, 'G-C \\1')
      .gsub(/a_t_(skew)/, 'A-T \\1')
      .gsub(/x_content/, &:capitalize)
      .gsub(/(^|_)([sl]su|a[an]i)(_|$)/, &:upcase)
      .gsub(/^trna_/, 'tRNA ')
      .gsub(/tRNA aa/, 'tRNA AA')
      .tr('_', ' ')
  end

  ##
  # Wraps the string with fixed Integer +width+.
  def wrap_width(width)
    gsub(/([^\n\r]{1,#{width}})/, "\\1\n")
  end

  ##
  # Replace {{variables}} using the +vars+ hash
  def miga_variables(vars)
    o = self.dup
    vars.each { |k, v| o.gsub!("{{#{k}}}", v.to_s) }
    o
  end
end
