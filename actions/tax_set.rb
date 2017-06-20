#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {q:true}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset_opt])
  opt.on("-s", "--tax-string STRING",
    "String corresponding to the taxonomy of the dataset.",
    "The MiGA format of string taxonomy is a space-delimited",
    "set of 'rank:name' pairs."){ |v| o[:taxstring]=v }
  opt.on("-t", "--tax-file PATH",
    "(Mandatory unless -D and -s are provided) Tab-delimited file containing",
    "datasets taxonomy.  Each row corresponds to a datasets and each column",
    "corresponds to a rank.  The first row must be a header with the rank ",
    "names, and the first column must contain dataset names."
    ){ |v| o[:taxfile]=v }
  opt_common(opt, o)
end.parse!

##=> Main <=
opt_require(o, project:"-P")
raise "-D is mandatory unless -t is provided." if
  o[:dataset].nil? and o[:taxfile].nil?
raise "-s is mandatory unless -t is provided." if
  o[:taxstring].nil? and o[:taxfile].nil?

$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

if not o[:taxfile].nil?
  $stderr.puts "Reading tax-file and registering taxonomy." unless o[:q]
  tfh = File.open(o[:taxfile], "r")
  header = nil
  tfh.each_line do |ln|
    next if ln =~ /^\s*?$/
    r = ln.chomp.split(/\t/, -1)
    dn = r.shift
    if header.nil?
      header = r
      next
    end
    d = p.dataset dn
    if d.nil?
      warn "Impossible to find dataset at line #{$.}: #{dn}. Ignoring..."
      next
    end
    d.metadata[:tax] = MiGA::Taxonomy.new(r, header)
    d.save
    $stderr.puts " #{d.name} registered." unless o[:q]
  end
  tfh.close
else
  $stderr.puts "Registering taxonomy." unless o[:q]
  d = p.dataset o[:dataset]
  d.metadata[:tax] = MiGA::Taxonomy.new(o[:taxstring])
  d.save
end

$stderr.puts "Done." unless o[:q]
