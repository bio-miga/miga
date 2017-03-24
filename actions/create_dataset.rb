#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, ref:true, update:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset, :dataset_type_req])
  opt.on("-q", "--query",
    "If set, the dataset is registered as a query, not a reference dataset."
    ){ |v| o[:ref]=!v }
  opt.on("-d", "--description STRING",
    "Description of the dataset."){ |v| o[:description]=v }
  opt.on("-u", "--user STRING",
    "Owner of the dataset."){ |v| o[:user]=v }
  opt.on("-c", "--comments STRING",
    "Comments on the dataset."){ |v| o[:comments]=v }
  opt.on("-m", "--metadata STRING",
    "Metadata as key-value pairs separated by = and delimited by comma.",
    "Values are saved as strings except for booleans (true / false) or nil."
    ){ |v| o[:metadata]=v }
  opt.on("--update",
    "Updates the dataset if it already exists."){ o[:update]=true }
  opt_common(opt, o)
  opt.separator ""
  opt.separator "External input data"
  opt.on("--raw-reads FILE1,FILE2", Array,
    "Comma-delimited paths to the raw reads in FastQ format.",
    "One file is assumed to be single reads, two are assumed to be paired."
    ){ |v| o[:raw_reads] = v }
  opt.on("--trimmed-fasta-single FILE", Array,
    "Path to the single trimmed reads in FastA format."
    ){ |v| o[:trimmed_fasta_s] = v }
  opt.on("--trimmed-fasta-coupled FILE1,FILE2", Array,
    "Comma-delimited paths to the coupled trimmed reads in FastA format.",
    "One file is assumed to be interposed, two are assumed to contain sisters."
    ){ |v| o[:trimmed_fasta_c] = v }
  opt.on("--assembly FILE", Array,
    "Path to the contigs (or scaffolds) of the assembly in FastA format."
    ){ |v| o[:assembly] = v }
end.parse!

##=> Main <=
opt_require(o)
opt_require(o, type:"-t")

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

raise "Dataset already exists, aborting." unless
  o[:update] or not MiGA::Dataset.exist?(p, o[:dataset])
$stderr.puts "Loading dataset." unless o[:q]
d = o[:update] ? p.dataset(o[:dataset]) :
  MiGA::Dataset.new(p, o[:dataset], o[:ref], {})
raise "Dataset does not exist." if d.nil?

in_files = [:raw_reads, :trimmed_fasta_s, :trimmed_fasta_c, :assembly]
def cp_result(o, d, p, sym, res_sym, ext)
  return if o[sym].nil? or o[sym].empty?
  r_dir  = MiGA::Dataset.RESULT_DIRS[res_sym]
  r_path = File.expand_path("data/#{r_dir}/#{d.name}", p.path)
  ext.each_index do |i|
    FileUtils.cp o[sym][i], "#{r_path}#{ext[i]}" unless o[sym][i].nil?
  end
  File.open("#{r_path}.done", "w") { |f| f.print Time.now.to_s }
end
if in_files.any? { |i| not o[i].nil? }
  $stderr.puts "Copying files." unless o[:q]
  # :raw_reads
  cp_result(o, d, p, :raw_reads, :raw_reads, %w[.1.fastq .2.fastq])
  # :trimmed_fasta
  cp_result(o, d, p, :trimmed_fasta_s, :trimmed_fasta, %w[.SingleReads.fa])
  if (o[:trimmed_fasta_c] || []).size > 1
    cp_result(o, d, p, :trimmed_fasta_c, :trimmed_fasta, %w[.1.fasta .2.fasta])
  else
    cp_result(o, d, p, :trimmed_fasta_c, :trimmed_fasta, %w[.CoupledReads.fa])
  end
  # :assembly
  cp_result(o, d, p, :assembly, :assembly, %w[.LargeContigs.fna])
end

unless o[:metadata].nil?
  o[:metadata].split(",").each do |pair|
    (k,v) = pair.split("=")
    case v
      when "true";  v = true
      when "false"; v = false
      when "nil";   v = nil
    end
    d.metadata[k] = v
  end
end
[:type, :description, :user, :comments].each do |k|
  d.metadata[k]=o[k] unless o[k].nil?
end

d.save
p.add_dataset(o[:dataset]) unless o[:update]
res = d.first_preprocessing(true)
$stderr.puts "- #{res}" unless o[:q]

$stderr.puts "Done." unless o[:q]
