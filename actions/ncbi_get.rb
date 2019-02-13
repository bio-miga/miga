#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require 'miga/remote_dataset'
require 'csv'

o = {q:true, query:false, unlink:false,
  reference: false, legacy_name: false,
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
    'Download all reference genomes (ignores any other status).'
    ){ |v| o[:reference]=v }
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
  opt.on('--legacy-name',
    'Use dataset names based on chromosome entries instead of assembly.'
    ){ |v| o[:legacy_name] = v }
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
  opt.on('--api-key STRING', 'NCBI API key.'){ |v| ENV['NCBI_API_KEY'] = v }
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

url_base = 'https://www.ncbi.nlm.nih.gov/genomes/solr2txt.cgi?'
url_param = {
  q: '[display()].' +
    'from(GenomeAssemblies).' +
    'usingschema(/schema/GenomeAssemblies).' +
    'matching(tab==["Prokaryotes"] and q=="' + o[:taxon].tr('"',"'") + '"',
  fields: 'organism|organism,assembly|assembly,replicons|replicons,' +
    'level|level,ftp_path_genbank|ftp_path_genbank,release_date|release_date,' +
    'strain|strain',
  nolimit: 'on',
}
if o[:reference]
  url_param[:q] += ' and refseq_category==["representative"]'
else
  status = {
    complete: 'Complete',
    chromosome: ' Chromosome', # <- The leading space is *VERY* important!
    scaffold: 'Scaffold',
    contig: 'Contig'
  }.map { |k, v| '"' + v + '"' if o[k] }.compact.join(',')
  url_param[:q] += ' and level==[' + status + ']'
end
url_param[:q] += ')'
url = url_base + URI.encode_www_form(url_param)
$stderr.puts 'Downloading genome list' unless o[:q]
lineno = 0
doc = MiGA::RemoteDataset.download_url(url)
CSV.parse(doc, headers: true).each do |r|
  asm = r['assembly']
  next if asm.nil? or asm.empty? or asm == '-'

  # Get replicons
  rep = r['replicons'].nil? ? nil : r['replicons'].
      split('; ').map{ |i| i.gsub(/.*:/,'') }.map{ |i| i.gsub(/\/.*/, '') }

  # Set name
  if o[:legacy_name] and o[:reference]
    n = r['#organism'].miga_name
  else
    if o[:legacy_name] and ['Complete',' Chromosome'].include? r['level']
      acc = rep.nil? ? '' : rep.first
    else
      acc = asm
    end
    acc.gsub!(/\.\d+\Z/, '') unless o[:add_version]
    n = "#{r['#organism']}_#{acc}".miga_name
  end

  # Register for download
  fna_url = r['ftp_path_genbank'] + '/' +
    File.basename(r['ftp_path_genbank']) + '_genomic.fna.gz'
  ds[n] = {
    ids: [fna_url], db: :assembly_gz, universe: :web,
    md: {
      type: :genome, ncbi_asm: asm, strain: r['strain']
    }
  }
  ds[n][:md][:ncbi_nuccore] = rep.join(',') unless rep.nil?
  ds[n][:md][:release_date] =
    Time.parse(r['release_date']).to_s unless r['release_date'].nil?
end

# Discard blacklisted
unless o[:blacklist].nil?
  $stderr.puts "Discarding datasets in #{o[:blacklist]}." unless o[:q]
  File.readlines(o[:blacklist]).
    select{ |i| i !~ /^#/ }.map(&:chomp).each{ |i| ds.delete i }
end

# Download entries
$stderr.puts "Downloading #{ds.size} " +
  (ds.size == 1 ? "entry" : "entries") unless o[:q]
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

