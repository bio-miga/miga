#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

input_types = {
  raw_reads_single: 
    ['Single raw reads in a single FastQ file',
      :raw_reads, %w[.1.fastq]],
  raw_reads_paired: 
    ['Paired raw reads in two FastQ files',
      :raw_reads, %w[.1.fastq .2.fastq]],
  trimmed_reads_single: 
    ['Single trimmed reads in a single FastA file',
      :trimmed_fasta, %w[.SingleReads.fa]],
  trimmed_reads_paired: 
    ['Paired trimmed reads in two FastA files',
      :trimmed_fasta, %w[.1.fasta .2.fasta]],
  trimmed_reads_interleaved: 
    ['Paired trimmed reads in a single FastA file',
      :trimmed_fasta, %w[.CoupledReads.fa]],
  assembly: 
    ['Assembled contigs or scaffolds in FastA format',
      :assembly, %w[.LargeContigs.fna]]
}

o = {q: true, ref: true, ignore_dups: false,
  regexp: /^(?:.*\/)?(.+?)(?:\..*(?:[12]|Reads|Contigs))?(?i:\.f[nastq]+)?$/}
OptionParser.new do |opt|
  opt_banner(opt, true)
  opt_object(opt, o, [:project, :dataset_opt, :dataset_type_req])
  opt.on('-q', '--query',
    'If set, the dataset is registered as a query, not a reference dataset.'
    ){ |v| o[:ref] = !v }
  opt.on('-d', '--description STRING',
    'Description of the dataset.'){ |v| o[:description] = v }
  opt.on('-c', '--comments STRING',
    'Comments on the dataset.'){ |v| o[:comments] = v }
  opt.on('-m', '--metadata STRING',
    'Metadata as key-value pairs separated by = and delimited by comma.',
    'Values are saved as strings except for booleans (true / false) or nil.'
    ){ |v| o[:metadata] = v }
  opt.on('-r', '--name-regexp REGEXP', Regexp,
    'Regular expression indicating how to extract the name from the file path.',
    "By default: '#{o[:regexp]}'"){ |v| o[:regexp] = v }
  opt.on('-i', '--input-type STRING',
    'Type of input data, one of the following:',
    *input_types.map{ |k,v| "~ #{k}: #{v[0]}." }
    ){ |v| o[:input_type] = v.downcase.to_sym }
  opt.on('--ignore-dups', 'Continue with a warning if a dataset already exists.'
    ){ |v| o[:ignore_dups] = v }
  opt_common(opt, o)

  opt.separator 'You can create multiple datasets with a single command, ' \
    'simply pass all the files at the end (FILES...).'
  opt.separator 'If -D is passed, only one dataset will be added. ' \
    'Otherwise, dataset names will be determined by the file paths (-r).'
  opt.separator ''
end.parse!

##=> Main <=
opt_require(o, project: '-P')
files = ARGV
file_type = nil
if files.empty?
  opt_require_type(o, MiGA::Dataset)
  files = [nil]
else
  raise 'Please specify input type (-i).' if o[:input_type].nil?
  file_type = input_types[o[:input_type]]
  raise "Unrecognized input type: #{o[:input_type]}." if file_type.nil?
  raise 'Some files are duplicated, files must be unique.' if
    files.size != files.uniq.size
  if o[:input_type].to_s =~ /_paired$/
    raise 'Odd number of files incompatible with input type.' if files.size.odd?
    files = Hash[*files].to_a
  else
    files = files.map{ |i| [i] }
  end
  raise 'The dataset name (-D) can only be specified with one input file.' if
    files.size > 1 and not o[:dataset].nil?
end

$stderr.puts 'Loading project.' unless o[:q]
p = MiGA::Project.load(o[:project])
raise "Impossible to load project: #{o[:project]}" if p.nil?

$stderr.puts 'Creating datasets:' unless o[:q]
files.each do |file|
  name = o[:dataset]
  if name.nil?
    ref_file = file.is_a?(Array) ? file.first : file
    m = o[:regexp].match(ref_file)
    raise "Cannot extract name from file: #{ref_file}" if m.nil? or m[1].nil?
    name = m[1].miga_name
  end

  if MiGA::Dataset.exist?(p, name)
    if o[:ignore_dups]
      warn "Dataset already exists: #{name}."
      next
    else
      raise "Dataset already exists: #{name}."
    end
  end

  $stderr.puts "o #{name}" unless o[:q]
  d = MiGA::Dataset.new(p, name, o[:ref])
  raise "Unexpected: Couldn't create dataset: #{name}." if d.nil?

  unless file.nil?
    r_dir = MiGA::Dataset.RESULT_DIRS[ file_type[1] ]
    r_path = File.expand_path("data/#{r_dir}/#{d.name}", p.path)
    file_type[2].each_with_index do |ext, i|
      gz = file[i] =~ /\.gz/ ? '.gz' : ''
      FileUtils.cp(file[i], "#{r_path}#{ext}#{gz}")
      $stderr.puts "  file: #{file[i]}" unless o[:q]
    end
    File.open("#{r_path}.done", 'w') { |f| f.print Time.now.to_s }
  end
  
  d = add_metadata(o, d)
  d.save
  p.add_dataset(name)
  res = d.first_preprocessing(true)
  $stderr.puts "  result: #{res}" unless o[:q]
end

$stderr.puts 'Done.' unless o[:q]
