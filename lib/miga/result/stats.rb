require 'miga/result/base'

##
# Helper module including stats-specific functions for results
module MiGA::Result::Stats
  ##
  # (Re-)calculate and save the statistics for the result
  def compute_stats
    method = :"compute_stats_#{key}"
    MiGA::MiGA.DEBUG "Result(#{key}).compute_stats"
    stats = self.respond_to?(method, true) ? send(method) : nil
    unless stats.nil?
      self[:stats] = stats
      save
    end
    self[:stats]
  end

  ##
  # Access the stats entry of results
  def stats
    self[:stats]
  end

  private

  def compute_stats_raw_reads
    stats = {}
    seq_opts = { gc: true, x: true, skew: true }
    if self[:files][:pair1].nil?
      s = MiGA::MiGA.seqs_length(file_path(:single), :fastq, seq_opts)
      stats = {
        reads: s[:n],
        length_average: [s[:avg], 'bp'],
        length_standard_deviation: [s[:sd], 'bp'],
        g_c_content: [s[:gc], '%'],
        x_content: [s[:x], '%'],
        g_c_skew: [s[:gc_skew], '%'],
        a_t_skew: [s[:at_skew], '%']
      }
    else
      s1 = MiGA::MiGA.seqs_length(file_path(:pair1), :fastq, seq_opts)
      s2 = MiGA::MiGA.seqs_length(file_path(:pair2), :fastq, seq_opts)
      stats = {
        read_pairs: s1[:n],
        forward_length_average: [s1[:avg], 'bp'],
        forward_length_standard_deviation: [s1[:sd], 'bp'],
        forward_g_c_content: [s1[:gc], '%'],
        forward_x_content: [s1[:x], '%'],
        forward_g_c_skew: [s1[:gc_skew], '%'],
        forward_a_t_skew: [s1[:at_skew], '%'],
        reverse_length_average: [s2[:avg], 'bp'],
        reverse_length_standard_deviation: [s2[:sd], 'bp'],
        reverse_g_c_content: [s2[:gc], '%'],
        reverse_x_content: [s2[:x], '%'],
        reverse_g_c_skew: [s2[:gc_skew], '%'],
        reverse_a_t_skew: [s2[:at_skew], '%']
      }
    end
    stats
  end

  def compute_stats_trimmed_fasta
    f = self[:files][:coupled].nil? ? file_path(:single) : file_path(:coupled)
    s = MiGA::MiGA.seqs_length(f, :fasta, gc: true, x: true, skew: true)
    {
      reads: s[:n],
      length_average: [s[:avg], 'bp'],
      length_standard_deviation: [s[:sd], 'bp'],
      g_c_content: [s[:gc], '%'],
      x_content: [s[:x], '%'],
      g_c_skew: [s[:gc_skew], '%'],
      a_t_skew: [s[:at_skew], '%']
    }
  end

  def compute_stats_assembly
    s = MiGA::MiGA.seqs_length(
      file_path(:largecontigs), :fasta,
      n50: true, gc: true, x: true, skew: true
    )
    {
      contigs: s[:n],
      n50: [s[:n50], 'bp'],
      total_length: [s[:tot], 'bp'],
      longest_sequence: [s[:max], 'bp'],
      g_c_content: [s[:gc], '%'],
      x_content: [s[:x], '%'],
      g_c_skew: [s[:gc_skew], '%'],
      a_t_skew: [s[:at_skew], '%']
    }
  end

  def compute_stats_cds
    s = MiGA::MiGA.seqs_length(file_path(:proteins), :fasta)
    stats = {
      predicted_proteins: s[:n],
      average_length: [s[:avg], 'aa']
    }
    asm = source.result(:assembly)
    unless asm.nil? or asm[:stats][:total_length].nil?
      stats[:coding_density] =
        [300.0 * s[:tot] / asm[:stats][:total_length][0], '%']
    end
    if file_path(:gff3) && file_path(:gff3) =~ /\.gz/
      Zlib::GzipReader.open(file_path(:gff3)) do |fh|
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
    if source.multi?
      stats = { median_copies: 0, mean_copies: 0 }
      File.open(file_path(:report), 'r') do |fh|
        fh.each_line do |ln|
          if /^! (Mean|Median) number of copies per model: (.*)\./.match(ln)
            stats["#{$1.downcase}_copies".to_sym] = $2.to_f
          end
        end
      end
    else
      # Estimate quality metrics
      fix_essential_genes_by_domain
      stats = { completeness: [0.0, '%'], contamination: [0.0, '%'] }
      File.open(file_path(:report), 'r') do |fh|
        fh.each_line do |ln|
          if /^! (Completeness|Contamination): (.*)%/.match(ln)
            stats[$1.downcase.to_sym][0] = $2.to_f
          end
        end
      end

      # Determine qualitative range
      stats[:quality] = stats[:completeness][0] - stats[:contamination][0] * 5
      source.metadata[:quality] =
        if stats[:completeness][0] >= 90 && stats[:contamination][0] <= 5
          :excellent    # Finished or High-quality draft*
        elsif stats[:completeness][0] >= 50 && stats[:contamination][0] <= 10
          :high         # Medium-quality draft*
        elsif stats[:quality] >= 25
          :intermediate # Low-quality draft* but sufficient for classification
        else
          :low          # Low-quality draft* and insufficient for classification
        end
        # * Bowers et al 2017, DOI: 10.1038/nbt.3893
      source.save

      # Inactivate low-quality datasets
      min_qual = project.option(:min_qual)
      if min_qual != 'no' && stats[:quality] < min_qual
        source.inactivate! 'Low quality genome'
      end
    end
    stats
  end

  def compute_stats_ssu
    stats = {
      ssu: 0, complete_ssu: 0, ssu_fragment: [0.0, '%'],
      lsu: 0, complete_lsu: 0, lsu_fragment: [0.0, '%']
    }

    subunits = {
      '16S_rRNA' => :ssu, '23S_rRNA' => :lsu,
      '18S_rRNA' => :ssu, '28S_rRNA' => :lsu
    }
    Zlib::GzipReader.open(file_path(:gff)) do |fh|
      fh.each_line do |ln|
        next if ln =~ /^#/

        rl = ln.chomp.split("\t")
        feat = Hash[rl[8].split(';').map { |i| i.split('=', 2) }]
        subunit = subunits[feat['Name']] or next # Ignore 5S

        if subunit == :ssu
          len = (rl[4].to_i - rl[3].to_i).abs + 1
          stats[:max_length] = [stats[:max_length] || 0, len].max
        end

        stats[subunit] += 1
        if feat['product'] =~ /\(partial\)/
          if feat['note'] =~ /aligned only (\d+) percent/
            fragment = $1.to_f
            if fragment > stats[:"#{subunit}_fragment"][0]
              stats[:"#{subunit}_fragment"][0] = fragment
            end
          end
        else
          stats[:"complete_#{subunit}"] += 1
          stats[:"#{subunit}_fragment"][0] = 100.0
        end
      end
    end

    Zlib::GzipReader.open(file_path(:trna_list)) do |fh|
      no = 0
      stats[:trna_count] = 0
      aa = {}
      fh.each_line do |ln|
        next if (no += 1) < 4
        stats[:trna_count] += 1
        row = ln.chomp.split("\t")
        next if row[9] == 'pseudo' || row[4] == 'Undet'
        aa[row[4].gsub(/^[a-z]?([A-Za-z]+)[0-9]?/, '\1')] = true
      end
      stats[:trna_aa] = aa.size
    end if file_path(:trna_list)

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
        next unless ln.chomp =~ /^\s*(\S+)\s+(.+)\s+([0-9\.e-]+)\s+\**\s*$/

        stats[:"#{$1}_pvalue"] = $3.to_f unless $1 == 'root'
      end
    end
    stats
  end

  # Fix estimates based on essential genes based on taxonomy
  def fix_essential_genes_by_domain
    return if file_path(:raw_report)

    tax = source.metadata[:tax]
    return unless tax.nil? || %w[Archaea Bacteria].include?(tax[:d])

    domain = tax.nil? ? 'AB' : tax[:d][0]
    MiGA::MiGA.DEBUG "Fixing essential genes by domain"
    scr = File.join(MiGA::MiGA.root_path, 'utils', 'domain-ess-genes.rb')
    rep = file_path(:report)
    $stderr.print MiGA::MiGA.run_cmd(
      ['ruby', scr, rep, "#{rep}.domain", domain],
      return: :output, err2out: true, source: :miga
    )
    add_file(:raw_report, "#{source.name}.ess/log")
    add_file(:report, "#{source.name}.ess/log.domain")
  end
end
