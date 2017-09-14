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
    scr = "awk 'NR%4==2{L+=length($0)} END{print NR/4, L*4/NR}'"
    if r[:files][:pair1].nil?
      s = `#{scr} '#{r.file_path :single}'`.chomp.split(" ")
      stats = {reads: s[0].to_i, average_length: [s[1].to_f, "bp"]}
    else
      s1 = `#{scr} '#{r.file_path :pair1}'`.chomp.split(" ")
      s2 = `#{scr} '#{r.file_path :pair2}'`.chomp.split(" ")
      stats = {read_pairs: s1[0].to_i,
        average_length_forward: [s1[1].to_f, "bp"],
        average_length_reverse: [s2[1].to_f, "bp"]}
    end
  when :trimmed_fasta
    scr = "awk '{L+=$2} END{print NR, L/NR}'"
    f = r[:files][:coupled].nil? ? r.file_path(:single) : r.file_path(:coupled)
    s = `FastA.length.pl '#{f}' | #{scr}`.chomp.split(" ")
    stats = {reads: s[0].to_i, average_length: [s[1].to_f, "bp"]}
  when :assembly
    f = r.file_path :largecontigs
    s = `FastA.N50.pl '#{f}'`.chomp.split("\n").map{|i| i.gsub(/.*: /,'').to_i}
    stats = {contigs: s[1], n50: [s[0], "bp"], total_length: [s[2], "bp"]}
  when :cds
    scr = "awk '{L+=$2} END{print NR, L/NR}'"
    f = r.file_path :proteins
    s = `FastA.length.pl '#{f}' | #{scr}`.chomp.split(" ")
    stats = {predicted_proteins: s[0].to_i, average_length: [s[1].to_f, "aa"]}
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
            d.metadata[:tax].is_in? MiGA::Taxonomy.new("d:Archaea") and
            r.file_path(:bac_report).nil?
        scr = "#{MiGA::MiGA.root_path}/utils/arch-ess-genes.rb"
        rep = r.file_path(:report)
        $stderr.print `ruby '#{scr}' '#{rep}' '#{rep}.archaea'`
        r.add_file(:bac_report, "#{d.name}.ess/log")
        r.add_file(:report, "#{d.name}.ess/log.archaea")
      end
      # Extract/compute quality values
      stats = {completeness:[0.0,"%"], contamination:[0.0,"%"]}
      File.open(r.file_path(:report), "r") do |fh|
        fh.each_line do |ln|
          if /^! (Completeness|Contamination): (.*)%/.match(ln)
            stats[$1.downcase.to_sym][0] = $2.to_f
          end
        end
      end
      stats[:quality] = stats[:completeness][0] - stats[:contamination][0]*5
      q_range = stats[:quality] > 80.0 ? :excellent :
        stats[:quality] > 50.0 ? :high :
        stats[:quality] > 20.0 ? :intermediate : :low
      d.metadata[:quality] = q_range
      d.save
    end
  when :distances
    d.cleanup_distances! unless d.nil?
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
    puts "#{k.to_s.unmiga_name.capitalize}: #{
      v.is_a?(Array) ? v.join(" ") : v}."
  end
else
  v = r[:stats][o[:key].downcase.miga_name.to_sym]
  puts v.is_a?(Array) ? v.first : v
end

$stderr.puts "Done." unless o[:q]
