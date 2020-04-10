
require 'miga/result/base'

##
# Helper module including stats-specific functions for results
module MiGA::Result::Stats

  ##
  # (Re-)calculate and save the statistics for the result
  def compute_stats
    method = :"compute_stats_#{key}"
    stats = self.respond_to?(method, true) ? send(method) : nil
    unless stats.nil?
      self[:stats] = stats
      save
    end
    self[:stats]
  end

  private

  def compute_stats_raw_reads
    stats = {}
    if self[:files][:pair1].nil?
      s = MiGA::MiGA.seqs_length(file_path(:single), :fastq, gc: true)
      stats = {
        reads: s[:n],
        length_average: [s[:avg], 'bp'],
        length_standard_deviation: [s[:sd], 'bp'],
        g_c_content: [s[:gc], '%']}
    else
      s1 = MiGA::MiGA.seqs_length(file_path(:pair1), :fastq, gc: true)
      s2 = MiGA::MiGA.seqs_length(file_path(:pair2), :fastq, gc: true)
      stats = {
        read_pairs: s1[:n],
        forward_length_average: [s1[:avg], 'bp'],
        forward_length_standard_deviation: [s1[:sd], 'bp'],
        forward_g_c_content: [s1[:gc], '%'],
        reverse_length_average: [s2[:avg], 'bp'],
        reverse_length_standard_deviation: [s2[:sd], 'bp'],
        reverse_g_c_content: [s2[:gc], '%']}
    end
    stats
  end

  def compute_stats_trimmed_fasta
    f = self[:files][:coupled].nil? ? file_path(:single) : file_path(:coupled)
    s = MiGA::MiGA.seqs_length(f, :fasta, gc: true)
    {
      reads: s[:n],
      length_average: [s[:avg], 'bp'],
      length_standard_deviation: [s[:sd], 'bp'],
      g_c_content: [s[:gc], '%']
    }
  end

  def compute_stats_assembly
    s = MiGA::MiGA.seqs_length(file_path(:largecontigs), :fasta,
      n50: true, gc: true)
    {
      contigs: s[:n],
      n50: [s[:n50], 'bp'],
      total_length: [s[:tot], 'bp'],
      g_c_content: [s[:gc], '%']
    }
  end

  def compute_stats_cds
    s = MiGA::MiGA.seqs_length(file_path(:proteins), :fasta)
    stats = {
      predicted_proteins: s[:n],
      average_length: [s[:avg], 'aa']}
    asm = source.result(:assembly)
    unless asm.nil? or asm[:stats][:total_length].nil?
      stats[:coding_density] =
        [300.0 * s[:tot] / asm[:stats][:total_length][0], '%']
    end
    if file_path(:gff3) && file_path(:gff3) =~ /\.gz/
      GzipReader.open(file_path(:gff3)) do |fh|
        fh.each do |ln|
          if ln =~ /^# Model Data:.*;transl_table=(\d+);/
            stats[:codon_table] = $1
            break
          end
        end
      end
    end
    stats
  end

  def compute_stats_essential_genes
    stats = {}
    if source.is_multi?
      stats = {median_copies: 0, mean_copies: 0}
      File.open(file_path(:report), 'r') do |fh|
        fh.each_line do |ln|
          if /^! (Mean|Median) number of copies per model: (.*)\./.match(ln)
            stats["#{$1.downcase}_copies".to_sym] = $2.to_f
          end
        end
      end
    else
      # Fix estimate by domain
      if !(tax = source.metadata[:tax]).nil? &&
            %w[Archaea Bacteria].include?(tax[:d]) &&
            file_path(:raw_report).nil?
        scr = "#{MiGA::MiGA.root_path}/utils/domain-ess-genes.rb"
        rep = file_path(:report)
        rc_p = File.expand_path('.miga_rc', ENV['HOME'])
        rc = File.exist?(rc_p) ? ". '#{rc_p}' && " : ''
        $stderr.print `#{rc} ruby '#{scr}' \
          '#{rep}' '#{rep}.domain' '#{tax[:d][0]}'`
        add_file(:raw_report, "#{source.name}.ess/log")
        add_file(:report, "#{source.name}.ess/log.domain")
      end
      # Extract/compute quality values
      stats = {completeness: [0.0, '%'], contamination: [0.0, '%']}
      File.open(file_path(:report), 'r') do |fh|
        fh.each_line do |ln|
          if /^! (Completeness|Contamination): (.*)%/.match(ln)
            stats[$1.downcase.to_sym][0] = $2.to_f
          end
        end
      end
      stats[:quality] = stats[:completeness][0] - stats[:contamination][0] * 5
      source.metadata[:quality] = case stats[:quality]
        when 80..100 ; :excellent
        when 50..80  ; :high
        when 20..50  ; :intermediate
        else         ; :low
      end
      source.save
    end
    stats
  end

  def compute_stats_ssu
    stats = {ssu: 0, complete_ssu: 0}
    Zlib::GzipReader.open(file_path(:gff)) do |fh|
      fh.each_line do |ln|
        next if ln =~ /^#/
        rl = ln.chomp.split("\t")
        len = (rl[4].to_i - rl[3].to_i).abs + 1
        stats[:max_length] = [stats[:max_length] || 0, len].max
        stats[:ssu] += 1
        stats[:complete_ssu] += 1 unless rl[8] =~ /\(partial\)/
      end
    end
    stats
  end

  def compute_stats_taxonomy
    stats = {}
    File.open(file_path(:intax_test), 'r') do |fh|
      fh.gets.chomp =~ /Closest relative: (\S+) with AAI: (\S+)\.?/
      stats[:closest_relative] = $1
      stats[:aai] = [$2.to_f, '%']
      3.times { fh.gets }
      fh.each_line do |ln|
        row = ln.chomp.gsub(/^\s*/,'').split(/\s+/)
        break if row.empty?
        stats[:"#{row[0]}_pvalue"] = row[2].to_f unless row[0] == 'root'
      end
    end
    stats
  end
end
