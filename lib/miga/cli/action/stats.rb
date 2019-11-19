# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Stats < MiGA::Cli::Action

  def parse_cli
    cli.defaults = {try_load: false}
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt, :result])
      opt.on(
        '--key STRING',
        'Return only the value of the requested key'
        ){ |v| cli[:key] = v }
      opt.on(
        '--compute-and-save',
        'Compute and saves the statistics'
        ){ |v| cli[:compute] = v }
      opt.on(
        '--try-load',
        'Check if stat exists instead of computing on --compute-and-save'
        ){ |v| cli[:try_load] = v }
    end
  end

  def perform
    cli[:compute] = false if cli[:try_load] and
      (not r[:stats].nil?) and (not r[:stats].empty?)
    r = cli.load_result
    if cli[:compute]
      cli.say 'Computing statistics'
      method = :"compute_#{cli[:result]}"
      stats = self.respond_to?(method, true) ? send(method, r) : nil
      unless stats.nil?
        r[:stats] = stats
        r.save
      end
    end
    if cli[:key].nil?
      r[:stats].each do |k,v|
        cli.puts "#{k==:g_c_content ? 'G+C content' : k.to_s.unmiga_name.capitalize}: #{
          v.is_a?(Array) ? v.join(' ') : v}."
      end
    else
      v = r[:stats][cli[:key].downcase.miga_name.to_sym]
      puts v.is_a?(Array) ? v.first : v
    end
  end

  private

  def compute_raw_reads(r)
    stats = {}
    if r[:files][:pair1].nil?
      s = MiGA.seqs_length(r.file_path(:single), :fastq, gc: true)
      stats = {
        reads: s[:n],
        length_average: [s[:avg], 'bp'],
        length_standard_deviation: [s[:sd], 'bp'],
        g_c_content: [s[:gc], '%']}
    else
      s1 = MiGA.seqs_length(r.file_path(:pair1), :fastq, gc: true)
      s2 = MiGA.seqs_length(r.file_path(:pair2), :fastq, gc: true)
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

  def compute_trimmed_fasta(r)
    f = r[:files][:coupled].nil? ? r.file_path(:single) : r.file_path(:coupled)
    s = MiGA.seqs_length(f, :fasta, gc: true)
    {
      reads: s[:n],
      length_average: [s[:avg], 'bp'],
      length_standard_deviation: [s[:sd], 'bp'],
      g_c_content: [s[:gc], '%']
    }
  end

  def compute_assembly(r)
    s = MiGA.seqs_length(r.file_path(:largecontigs), :fasta,
      n50: true, gc: true)
    {
      contigs: s[:n],
      n50: [s[:n50], 'bp'],
      total_length: [s[:tot], 'bp'],
      g_c_content: [s[:gc], '%']
    }
  end

  def compute_cds(r)
    s = MiGA.seqs_length(r.file_path(:proteins), :fasta)
    stats = {
      predicted_proteins: s[:n],
      average_length: [s[:avg], 'aa']}
    asm = cli.load_dataset.add_result(:assembly, false)
    unless asm.nil? or asm[:stats][:total_length].nil?
      stats[:coding_density] =
        [300.0 * s[:tot] / asm[:stats][:total_length][0], '%']
    end
    stats
  end

  def compute_essential_genes(r)
    stats = {}
    d = cli.load_dataset
    if d.is_multi?
      stats = {median_copies: 0, mean_copies: 0}
      File.open(r.file_path(:report), 'r') do |fh|
        fh.each_line do |ln|
          if /^! (Mean|Median) number of copies per model: (.*)\./.match(ln)
            stats["#{$1.downcase}_copies".to_sym] = $2.to_f
          end
        end
      end
    else
      # Fix estimate for Archaea
      if !d.metadata[:tax].nil? &&
            d.metadata[:tax].in?(Taxonomy.new('d:Archaea')) &&
            r.file_path(:bac_report).nil?
        scr = "#{MiGA.root_path}/utils/arch-ess-genes.rb"
        rep = r.file_path(:report)
        rc_p = File.expand_path('.miga_rc', ENV['HOME'])
        rc = File.exist?(rc_p) ? ". '#{rc_p}' && " : ''
        $stderr.print `#{rc} ruby '#{scr}' '#{rep}' '#{rep}.archaea'`
        r.add_file(:bac_report, "#{d.name}.ess/log")
        r.add_file(:report, "#{d.name}.ess/log.archaea")
      end
      # Extract/compute quality values
      stats = {completeness: [0.0, '%'], contamination: [0.0, '%']}
      File.open(r.file_path(:report), 'r') do |fh|
        fh.each_line do |ln|
          if /^! (Completeness|Contamination): (.*)%/.match(ln)
            stats[$1.downcase.to_sym][0] = $2.to_f
          end
        end
      end
      stats[:quality] = stats[:completeness][0] - stats[:contamination][0] * 5
      d.metadata[:quality] = case stats[:quality]
        when 80..100 ; :excellent
        when 50..80  ; :high
        when 20..50  ; :intermediate
        else         ; :low
      end
      d.save
    end
    stats
  end

  def compute_ssu(r)
    stats = {ssu: 0, complete_ssu: 0}
    Zlib::GzipReader.open(r.file_path(:gff)) do |fh|
      fh.each_line do |ln|
        next if ln =~ /^#/
        rl = ln.chomp.split("\t")
        len = (r[4].to_i - r[3].to_i).abs + 1
        stats[:max_length] = [stats[:max_length] || 0, len].max
        stats[:ssu] += 1
        stats[:complete_ssu] += 1 unless rl[8] =~ /\(partial\)/
      end
    end
    stats
  end

  def compute_taxonomy(r)
    stats = {}
    File.open(r.file_path(:intax_test), 'r') do |fh|
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
