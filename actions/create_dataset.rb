#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true, ref:true, update:false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset, :dataset_type])
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
  opt.on("--trimmed-fasta-single FILE",
    "Path to the single trimmed reads in FastA format."
    ){ |v| o[:trimmed_fasta_single] = v }
  opt.on("--trimmed-fasta-coupled FILE1,FILE2", Array,
    "Comma-delimited paths to the coupled trimmed reads in FastA format.",
    "One file is assumed to be interposed, two are assumed to contain sisters."
    ){ |v| o[:trimmed_fasta_coupled] = v }
  opt.on("--assembly FILE",
    "Path to the contigs (or scaffolds) of the assembly in FastA format."
    ){ |v| o[:assembly] = v }
end.parse!

##=> Main <=
opt_require(o)

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

raise "Dataset already exists, aborting." unless
  o[:update] or not MiGA::Dataset.exist?(p, o[:dataset])
$stderr.puts "Loading dataset." unless o[:q]
d = o[:update] ? p.dataset(o[:dataset]) :
  MiGA::Dataset.new(p, o[:dataset], o[:ref], {})
raise "Dataset does not exist." if d.nil?

in_files = [:raw_reads,:trimmed_fasta_single,:trimmed_fasta_coupled,:assembly]
def result_path(r, d, p)
  File.expand_path("data/#{MiGA::Dataset.RESULT_DIRS[r]}/#{d.name}", p)
end
def result_done(path)
  File.open("#{path}.done", "w") { |f| f.print Time.now.to_s }
end
if in_files.any? { |i| not o[i].nil? }
  $stderr.puts "Copying files." unless o[:q]
  # :raw_reads
  r_path = result_path(:raw_reads, d, p)
  unless o[:raw_reads].nil? or o[:raw_reads].empty?
    FileUtils.cp o[:raw_reads][0], "#{r_path}.1.fastq"
    FileUtils.cp o[:raw_reads][1], "#{r_path}.2.fastq" if o[:raw_reads].size > 1
    result_done(r_path)
  end
  # :trimmed_fasta
  r_path = result_path(:trimmed_fasta, d, p)
  unless o[:trimmed_fasta_single].nil? or o[:trimmed_fasta_single].empty?
    FileUtils.cp o[:trimmed_fasta_single], "#{r_path}.SingleReads.fa"
    result_done(r_path)
  end
  unless o[:trimmed_fasta_coupled].nil? or o[:trimmed_fasta_coupled].empty?
    if o[:trimmed_fasta_coupled].size == 1
      FileUtils.cp o[:trimmed_fasta_coupled][0], "#{r_path}.CoupledReads.fa"
    else
      FileUtils.cp o[:trimmed_fasta_coupled][0], "#{r_path}.1.fasta"
      FileUtils.cp o[:trimmed_fasta_coupled][0], "#{r_path}.2.fasta"
    end
    result_done(r_path)
  end
  # :assembly
  r_path = result_path(:assembly, d, p)
  unless o[:assembly].nil? or o[:assembly].empty?
    FileUtils.cp o[:assembly], "#{r_path}.LargeContigs.fna"
    result_done(r_path)
  end
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
