#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, try_load:false}
opts = OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt, :result])
  opt.on("--key STRING",
    "Returns only the value of the requested key."){ |v| o[:key] = v }
  opt.on("--compute-and-save",
    "Computes and saves the statistics."){ |v| o[:compute] = v }
  opt.on("--try-load",
    "Checks if stat exists instead of computing on --compute-and-save."
    ){ |v| o[:try_load] = v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opts.parse!
opt_require(o, project:"-P", name:"-r")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts "Loading result." unless o[:q]
d = nil
if o[:dataset].nil?
  r = p.add_result(o[:name], false)
else
  d = p.dataset(o[:dataset])
  r = d.add_result(o[:name], false)
end
raise "Cannot load result." if r.nil?

o[:compute] = false if o[:try_load] and
  (not r[:stats].nil?) and (not r[:stats].empty?)

if o[:compute]
  $stderr.puts "Computing statistics." unless o[:q]
  stats = {}
  case o[:name]
  when :raw_reads
    if r[:files][:pair1].nil?
      s = MiGA::MiGA.seqs_length(r.file_path(:single), :fastq, gc: true)
      stats = {
        reads: s[:n],
        length_average: [s[:avg], "bp"],
        length_standard_deviation: [s[:sd], "bp"],
        g_c_content: [s[:gc], "%"]}
    else
      s1 = MiGA::MiGA.seqs_length(r.file_path(:pair1), :fastq, gc: true)
      s2 = MiGA::MiGA.seqs_length(r.file_path(:pair2), :fastq, gc: true)
      stats = {
        read_pairs: s1[:n],
        forward_length_average: [s1[:avg], "bp"],
        forward_length_standard_deviation: [s1[:sd], "bp"],
        forward_g_c_content: [s1[:gc], "%"],
        reverse_length_average: [s2[:avg], "bp"],
        reverse_length_standard_deviation: [s2[:sd], "bp"],
        reverse_g_c_content: [s2[:gc], "%"]}
    end
  when :trimmed_fasta
    f = r[:files][:coupled].nil? ? r.file_path(:single) : r.file_path(:coupled)
    s = MiGA::MiGA.seqs_length(f, :fasta, gc: true)
    stats = {
      reads: s[:n],
      length_average: [s[:avg], "bp"],
      length_standard_deviation: [s[:sd], "bp"],
      g_c_content: [s[:gc], "%"]}
  when :assembly
    s = MiGA::MiGA.seqs_length(r.file_path(:largecontigs), :fasta,
      n50: true, gc: true)
    stats = {
      contigs: s[:n],
      n50: [s[:n50], "bp"],
      total_length: [s[:tot], "bp"],
      g_c_content: [s[:gc], "%"]}
  when :cds
    s = MiGA::MiGA.seqs_length(r.file_path(:proteins), :fasta)
    stats = {
      predicted_proteins: s[:n],
      average_length: [s[:avg], "aa"]}
    asm = d.add_result(:assembly, false)
    unless asm.nil? or asm[:stats][:total_length].nil?
      stats[:coding_density] =
        [300.0 * s[:tot] / asm[:stats][:total_length][0], "%"]
    end
  when :essential_genes
    if d.is_multi?
      stats = {median_copies:0, mean_copies:0}
      File.open(r.file_path(:report), "r") do |fh|
        fh.each_line do |ln|
          if /^! (Mean|Median) number of copies per model: (.*)\./.match(ln)
            stats["#{$1.downcase}_copies".to_sym] = $2.to_f
          end
        end
      end
    else
      # Fix estimate for Archaea
      if not d.metadata[:tax].nil? and
            d.metadata[:tax].in? MiGA::Taxonomy.new("d:Archaea") and
            r.file_path(:bac_report).nil?
        scr = "#{MiGA::MiGA.root_path}/utils/arch-ess-genes.rb"
        rep = r.file_path(:report)
        $stderr.print `ruby '#{scr}' '#{rep}' '#{rep}.archaea'`
        r.add_file(:bac_report, "#{d.name}.ess/log")
        r.add_file(:report, "#{d.name}.ess/log.archaea")
      end
      # Extract/compute quality values
      stats = {completeness: [0.0,"%"], contamination: [0.0,"%"]}
      File.open(r.file_path(:report), "r") do |fh|
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
  else
    stats = nil
  end
  unless stats.nil?
    r[:stats] = stats
    r.save
  end
end

if o[:key].nil?
  r[:stats].each do |k,v|
    puts "#{k==:g_c_content ? "G+C content" : k.to_s.unmiga_name.capitalize}: #{
      v.is_a?(Array) ? v.join(" ") : v}."
  end
else
  v = r[:stats][o[:key].downcase.miga_name.to_sym]
  puts v.is_a?(Array) ? v.first : v
end

$stderr.puts "Done." unless o[:q]
