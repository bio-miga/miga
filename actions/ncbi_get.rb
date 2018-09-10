#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require 'miga/remote_dataset'

o = {q:true, query:false, unlink:false,
      reference: false, ignore_plasmids: false,
      complete: false, chromosome: false,
      scaffold: false, contig: false, add_version: true, dry: false,
      get_md: false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project])
  opt.on('-T', '--taxon STRING',
        '(Mandatory unless --reference) Taxon name (e.g., a species binomial).'
        ){ |v| o[:taxon]=v }
  opt.on('--reference',
        'Download all reference genomes (ignores -T).'){ |v| o[:reference]=v }
  opt.on('--ref-no-plasmids',
        'If passed, ignores plasmids (only for --reference).'
        ){ |v| o[:ignore_plasmids]=v }
  opt.on('--complete', 'Download complete genomes.'){ |v| o[:complete]=v }
  opt.on('--chromosome',
        'Download complete chromosomes.'){ |v| o[:chromosome]=v }
  opt.on('--scaffold', 'Download genomes in scaffolds.'){ |v| o[:scaffold]=v }
  opt.on('--contig', 'Download genomes in contigs.'){ |v| o[:contig]=v }
  opt.on('--all', 'Download all genomes (in any status).') do
    o[:complete] = true
    o[:chromosome] = true
    o[:scaffold] = true
    o[:contig] = true
  end
  opt.on('--no-version-name',
        'Do not add sequence version to the dataset name.',
        'Only affects --complete and --chromosome.'){ |v| o[:add_version]=v }
  opt.on('--blacklist PATH',
        'A file with dataset names to blacklist.'){ |v| o[:blacklist] = v }
  opt.on('--dry', 'Do not download or save the datasets.'){ |v| o[:dry] = v }
  opt.on('--get-metadata',
        'Only download and update metadata for existing datasets'
        ){ |v| o[:get_md] = v }
  opt.on('-q', '--query',
        'Register the datasets as queries, not reference datasets.'
        ){ |v| o[:query]=v }
  opt.on('-u', '--unlink',
        'Unlink all datasets in the project missing from the download list.'
        ){ |v| o[:unlink]=v }
  opt.on('-R', '--remote-list PATH',
        'Path to an output file with the list of all datasets listed remotely.'
        ){ |v| o[:remote_list]=v }
  opt_common(opt, o)
end.parse!

opt_require(o, project: '-P')
opt_require(o, taxon: '-T') unless o[:reference]
unless %w[reference complete chromosome scaffold contig].any?{ |i| o[i.to_sym] }
  raise 'No action requested. Pick at least one type of genome.'
end

##=> Main <=
$stderr.puts "Loading project." unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?
d = []
ds = {}
downloaded = 0

def get_list(taxon, status)
  url_base = 'https://www.ncbi.nlm.nih.gov/genomes/Genome2BE/genome2srv.cgi?'
  url_param = if status==:reference
    { action: 'refgenomes', download: 'on' }
  else
    { action: 'download', report: 'proks', group: '-- All Prokaryotes --',
          subgroup: '-- All Prokaryotes --', orgn: "#{taxon}[orgn]",
          status: status }
  end
  url = url_base + URI.encode_www_form(url_param)
  response = RestClient::Request.execute(method: :get, url:url, timeout:600)
  unless response.code == 200
    raise "Unable to reach NCBI, error code #{response.code}."
  end
  response.to_s
end

# Download IDs with reference status
if o[:reference]
  $stderr.puts 'Downloading reference genomes' unless o[:q]
  lineno = 0
  get_list(nil, :reference).each_line do |ln|
    next if (lineno+=1)==1
    r = ln.chomp.split("\t")
    next if r[3].nil? or r[3].empty?
    ids = r[3].split(',')
    ids += r[5].split(',') unless o[:ignore_plasmids] or r[5].empty?
    ids.delete_if{ |i| i =~ /\A\-*\z/ }
    next if ids.empty?
    n = r[2].miga_name
    ds[n] = {ids: ids, md: {type: :genome}, db: :nuccore, universe: :ncbi}
  end
end

# Download IDs with complete or chromosome status
if o[:complete] or o[:chromosome]
  status = (o[:complete] and o[:chromosome] ?
        '50|40' : o[:complete] ? '50' : '40')
  $stderr.puts 'Downloading complete/chromosome genomes' unless o[:q]
  lineno = 0
  get_list(o[:taxon], status).each_line do |ln|
    next if (lineno+=1)==1
    r = ln.chomp.split("\t")
    next if r[10].nil? or r[10].empty?
    ids = r[10].gsub(/[^:;]*:/,'').gsub(/\/[^\/;]*/,'').split(';')
    ids.delete_if{ |i| i =~ /\A\-*\z/ }
    next if ids.empty?
    acc = o[:add_version] ? ids[0] : ids[0].gsub(/\.\d+\Z/,'')
    n = "#{r[0]}_#{acc}".miga_name
    ds[n] = {ids: ids, md: {type: :genome}, db: :nuccore, universe: :ncbi}
  end
end

# Download IDs with scaffold or contig status
if o[:scaffold] or o[:contig]
  status = (o[:scaffold] and o[:contig] ? '30|20' : o[:scaffold] ? '30' : '20')
  $stderr.puts "Downloading scaffold/contig genomes" unless o[:q]
  lineno = 0
  get_list(o[:taxon], status).each_line do |ln|
    next if (lineno+=1)==1
    r = ln.chomp.split("\t")
    next if r[7].nil? or r[7].empty?
    next if r[19].nil? or r[19].empty?
    asm = r[7].gsub(/[^:;]*:/,'').gsub(/\/[^\/;]*/,'').gsub(/\s/,'')
    ids = r[19].gsub(/\s/,'').split(';').delete_if{ |i| i =~ /\A\-*\z/ }.
          map{ |i| "#{i}/#{File.basename(i)}_genomic.fna.gz" }
    next if ids.empty?
    n = "#{r[0]}_#{asm}".miga_name
    %w[(contaminated) (partial)].each { |i| asm.delete! i }
    ds[n] = {ids: ids, md: {type: :genome, ncbi_asm: asm},
          db: :assembly_gz, universe: :web}
  end
end

# Discard blacklisted
unless o[:blacklist].nil?
  $stderr.puts "Discarding datasets in #{o[:blacklist]}." unless o[:q]
  File.readlines(o[:blacklist]).map(&:chomp).each{ |i| ds.delete i }
end

# Download entries
$stderr.puts "Downloading #{ds.size} " +
  (ds.size > 1 ? "entries" : "entry") unless o[:q]
ds.each do |name,body|
  d << name
  puts name
  next if p.dataset(name).nil? == o[:get_md]
  downloaded += 1
  next if o[:dry]
  $stderr.puts '  Locating remote dataset.' unless o[:q]
  rd = MiGA::RemoteDataset.new(body[:ids], body[:db], body[:universe])
  if o[:get_md]
    $stderr.puts '  Updating dataset.' unless o[:q]
    rd.update_metadata(p.dataset(name), body[:md])
  else
    $stderr.puts '  Creating dataset.' unless o[:q]
    rd.save_to(p, name, !o[:query], body[:md])
    p.add_dataset(name)
  end
end

# Finalize
$stderr.puts "Datasets listed: #{d.size}" unless o[:q]
$stderr.puts "Datasets #{o[:dry] ? 'to download' : 'downloaded'}: " +
  downloaded.to_s unless o[:q]
unless o[:remote_list].nil?
  File.open(o[:remote_list], 'w') do |fh|
    d.each { |i| fh.puts i }
  end
end
if o[:unlink]
  unlink = p.dataset_names - d
  unlink.each { |i| p.unlink_dataset(i).remove! }
  $stderr.puts "Datasets unlinked: #{unlink.size}" unless o[:q]
end

