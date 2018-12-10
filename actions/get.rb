#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

require 'miga/remote_dataset'

o = {q: true, query: false, universe: :ebi, db: :embl, get_md: false}
OptionParser.new do |opt|
  opt_banner(opt)
  opt_object(opt, o, [:project, :dataset, :dataset_type])
  opt.on('-I', '--ids ID1,ID2,...',
    '(Mandatory unless -F) IDs in the remote database separated by commas.'
    ){ |v| o[:ids]=v }
  opt.on('-U', '--universe STRING',
    "Universe where the remote database lives. By default: #{o[:universe]}."
    ){ |v| o[:universe]=v.to_sym }
  opt.on('--db STRING',
    "Name of the remote database. By default: #{o[:db]}."
    ){ |v| o[:db]=v.to_sym }
  opt.on('-F', '--file PATH',
    'Tab-delimited file (with header) listing the datasets to download.',
    'The long form of all the options are supported as header (without the --)',
    'including dataset, ids, universe, and db. For query use true/false values.'
    ){ |v| o[:file] = v }
  opt.on('-q', '--query',
    'If set, the dataset is registered as a query, not a reference dataset.'
    ){ |v| o[:query]=v }
  opt.on('--ignore-dup',
    'If set, ignores datasets that already exist.'){ |v| o[:ignore_dup]=v }
  opt.on('-d', '--description STRING',
    'Description of the dataset.'){ |v| o[:description]=v }
  opt.on('-c', '--comments STRING',
    'Comments on the dataset.'){ |v| o[:comments]=v }
  opt.on('-m', '--metadata STRING',
    'Metadata as key-value pairs separated by = and delimited by comma.',
    'Values are saved as strings except for booleans (true / false) or nil.'
    ){ |v| o[:metadata]=v }
  opt.on('--get-metadata',
    'Only download and update metadata for existing datasets'
    ){ |v| o[:get_md] = v }
  opt.on('--api-key STRING',
    'API key for the given universe.'){ |v| o[:api_key] = v }
  opt_common(opt, o)
end.parse!

##=> Main <=
glob = [o]
unless o[:file].nil?
  glob = []
  fh = File.open(o[:file], 'r')
  h = nil
  fh.each do |ln|
    r = ln.chomp.split(/\t/)
    if h.nil?
       h = r
    else
       glob << o.dup
       h.each_index do |i|
	 glob[glob.size-1][h[i].to_sym] = h[i]=='query' ? r[i]=='true' :
	   %w[type universe db].include?(h[i]) ? r[i].to_sym : r[i]
       end
    end
  end
  fh.close
end

glob.each do |o_i|
  opt_require(o_i, project: '-P', dataset: '-D', ids: '-I')
  unless o_i[:api_key].nil?
    ENV["#{o_i[:universe].to_s.upcase}_API_KEY"] = o_i[:api_key]
  end

  $stderr.puts "Dataset: #{o_i[:dataset]}" unless o_i[:q]
  $stderr.puts 'Loading project.' unless o_i[:q]
  p = MiGA::Project.load(o_i[:project])
  raise "Impossible to load project: #{o_i[:project]}" if p.nil?

  next if o_i[:ignore_dup] and not p.dataset(o_i[:dataset]).nil?

  $stderr.puts 'Locating remote dataset.' unless o_i[:q]
  rd = MiGA::RemoteDataset.new(o_i[:ids], o_i[:db], o_i[:universe])

  if o[:get_md]
    $stderr.puts 'Updating dataset.' unless o_i[:q]
    d = p.dataset(o_i[:dataset])
    next if d.nil?
    md = add_metadata(o_i, d).metadata.data
    rd.update_metadata(d, md)
  else
    $stderr.puts 'Creating dataset.' unless o_i[:q]
    dummy_d = MiGA::Dataset.new(p, o_i[:dataset])
    md = add_metadata(o_i, dummy_d).metadata.data
    dummy_d.remove!
    rd.save_to(p, o_i[:dataset], !o_i[:query], md)
    p.add_dataset(o_i[:dataset])
  end

  $stderr.puts 'Done.' unless o_i[:q]
end
