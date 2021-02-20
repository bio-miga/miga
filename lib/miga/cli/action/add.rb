# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Add < MiGA::Cli::Action
  def parse_cli
    cli.expect_files = true
    cli.defaults = { ref: true, ignore_dups: false }
    cli.parse do |opt|
      opt.separator 'You can create multiple datasets with a single command; ' \
        'simply pass all the files at the end: {FILES...}'
      opt.separator 'If -D is passed, only one dataset will be added. ' \
        'Otherwise, dataset names will be determined by the file paths (see -R)'
      opt.separator ''
      cli.opt_object(opt, [:project, :dataset_opt, :dataset_type_req])
      opt.on(
        '-q', '--query',
        'Register the dataset as a query, not a reference dataset'
      ) { |v| cli[:ref] = !v }
      opt.on(
        '-d', '--description STRING',
        'Description of the dataset'
      ) { |v| cli[:description] = v }
      opt.on(
        '-c', '--comments STRING',
        'Comments on the dataset'
      ) { |v| cli[:comments] = v }
      opt.on(
        '-m', '--metadata STRING',
        'Metadata as key-value pairs separated by = and delimited by comma',
        'Values are saved as strings except for booleans (true / false) or nil'
      ) { |v| cli[:metadata] = v }
      opt.on(
        '-R', '--name-regexp REGEXP', Regexp,
        'Regular expression indicating how to extract the name from the path',
        'By default for paired files:',
        "'#{MiGA::Cli.PAIRED_FILE_REGEXP}'",
        'By default for other files:',
        "'#{MiGA::Cli.FILE_REGEXP}'"
      ) { |v| cli[:regexp] = v }
      opt.on(
        '--prefix STRING',
        'Prefix to all the dataset names'
      ) { |v| cli[:prefix] = v }
      opt.on(
        '-i', '--input-type STRING',
        'Type of input data, one of the following:',
        *self.class.INPUT_TYPES.map { |k, v| "~ #{k}: #{v[0]}" }
      ) { |v| cli[:input_type] = v.downcase.to_sym }
      opt.on(
        '--ignore-dups',
        'Continue with a warning if a dataset already exists'
      ) { |v| cli[:ignore_dups] = v }
    end
  end

  def perform
    p = cli.load_project
    files, file_type = get_files_and_type

    cli[:regexp] ||=
      cli[:input_type].include?('_paired') ?
        MiGA::Cli.PAIRED_FILE_REGEXP : MiGA::Cli.FILE_REGEXP

    cli.say 'Creating datasets:'
    files.each do |file|
      d = create_dataset(file, p)
      next if d.nil?

      copy_file_to_project(file, file_type, d, p)
      cli.add_metadata(d)
      p.add_dataset(d.name)
      res = d.first_preprocessing(true)
      cli.say "  result: #{res}"
    end
  end

  @@INPUT_TYPES = {
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

  class << self
    def INPUT_TYPES
      @@INPUT_TYPES
    end
  end

  private

  def get_files_and_type
    files = cli.files
    file_type = nil
    if files.empty?
      cli.ensure_par({ dataset: '-D' },
                     'dataset is mandatory (-D) unless files are provided')
      cli.ensure_type(Dataset)
      files = [nil]
    else
      raise 'Please specify input type (-i).' if cli[:input_type].nil?

      file_type = self.class.INPUT_TYPES[cli[:input_type]]
      raise "Unrecognized input type: #{cli[:input_type]}." if file_type.nil?
      raise 'Some files are duplicated, files must be unique.' if
        files.size != files.uniq.size

      if cli[:input_type].to_s =~ /_paired$/
        if files.size.odd?
          raise 'Odd number of files incompatible with input type.'
        end

        files = Hash[*files].to_a
      else
        files = files.map { |i| [i] }
      end
      if files.size > 1 && !cli[:dataset].nil?
        raise 'The dataset name (-D) can only be specified with one input file.'
      end
    end
    [files, file_type]
  end

  def create_dataset(file, p)
    name = cli[:dataset]
    if name.nil?
      ref_file = file.is_a?(Array) ? file.first : file
      m = cli[:regexp].match(ref_file)
      raise "Cannot extract name from file: #{ref_file}" if m.nil? or m[1].nil?

      name = cli[:prefix].to_s + m[1].miga_name
    end
    if Dataset.exist?(p, name)
      msg = "Dataset already exists: #{name}."
      if cli[:ignore_dups]
        warn(msg)
        return nil
      else
        raise(msg)
      end
    end
    cli.say "o #{name}"
    d = Dataset.new(p, name, cli[:ref])
    raise "Unexpected: Couldn't create dataset: #{name}." if d.nil?

    d
  end

  def copy_file_to_project(file, file_type, d, p)
    return if file.nil?

    r_dir = Dataset.RESULT_DIRS[file_type[1]]
    r_path = File.expand_path("data/#{r_dir}/#{d.name}", p.path)
    file_type[2].each_with_index do |ext, i|
      gz = file[i] =~ /\.gz/ ? '.gz' : ''
      FileUtils.cp(file[i], "#{r_path}#{ext}#{gz}")
      cli.say "  file: #{file[i]}"
    end
    File.open("#{r_path}.done", 'w') { |f| f.print Time.now.to_s }
  end
end
