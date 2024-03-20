# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'miga/remote_dataset'

class MiGA::Cli::Action::Get < MiGA::Cli::Action
  require 'miga/cli/action/download/base'
  include MiGA::Cli::Action::Download::Base

  def parse_cli
    cli.defaults = {
      query: false, universe: :ncbi, db: :nuccore, get_md: false, only_md: false
    }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset, :dataset_type])
      opt.on(
        '-I', '--ids ID1,ID2,...', Array,
        '(Mandatory unless -F) IDs in the remote database separated by commas'
      ) { |v| cli[:ids] = v.map(&:strip) }
      opt.on(
        '-U', '--universe STRING',
        "Universe of the remote database. By default: #{cli[:universe]}",
        "Supported: #{MiGA::RemoteDataset.UNIVERSE.keys.join(', ')}"
      ) { |v| cli[:universe] = v.to_sym }
      opt.on(
        '--db STRING',
        "Name of the remote database. By default: #{cli[:db]}"
      ) { |v| cli[:db] = v.to_sym }
      opt.on(
        '-F', '--file PATH',
        'Tab-delimited file (with header) listing the datasets to download',
        'The long form of most options are supported as header (without --)',
        'including: dataset, ids, universe, db, metadata',
        'For flags without value (like query) use true/false',
        'Unsupported values are: project, file, verbose, help, and debug'
      ) { |v| cli[:file] = v }
      opt.on(
        '-q', '--query',
        'Register the dataset as a query, not a reference dataset'
      ) { |v| cli[:query] = v }
      opt.on(
        '--ignore-dup',
        'Ignore datasets that already exist'
      ) { |v| cli[:ignore_dup] = v }
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
        '--get-metadata',
        'Only download and update metadata for existing datasets'
      ) { |v| cli[:get_md] = v }
      opt.on(
        '--only-metadata',
        'Create datasets without input data but retrieve all metadata'
      ) { |v| cli[:only_md] = v }
      opt.on(
        '--bypass-metadata',
        'Do not gather optional metadata such as the dataset taxonomy'
      ) { |v| cli[:bypass_md] = v }
      opt.on(
        '--api-key STRING',
        'API key for the given universe'
      ) { |v| cli[:api_key] = v }
      opt.on(
        '--ncbi-taxonomy-dump [path]',
        'Path to an NCBI Taxonomy dump directory to query instead of API calls',
        'If the path is not passed, the dump is automatically downloaded'
      ) { |v| cli[:ncbi_taxonomy_dump] = v || true }
      opt.on(
        '--ignore-file', '::HIDE::' # Only for internal use
      ) { |v| cli[:ignore_file] = v }
    end
  end

  def perform
    glob = get_sub_cli
    p = cli.load_project
    load_ncbi_taxonomy_dump
    glob.each do |sub_cli|
      rd = create_remote_dataset(sub_cli, p)
      next if rd.nil?

      rd.metadata[:bypass_metadata] = true if sub_cli[:bypass_md]
      if sub_cli[:get_md]
        update_metadata(sub_cli, p, rd)
      else
        create_dataset(sub_cli, p, rd)
      end
    end
  end

  private

  def get_sub_cli
    return [cli] if cli[:file].nil? || cli[:ignore_file]

    glob = []
    cli_default = cli.original_argv + ['--ignore-file']
    File.open(cli[:file], 'r') do |fh|
      h = nil
      fh.each do |ln|
        r = ln.chomp.split(/\t/)
        if h.nil?
          h = r
        else
          argv_i = cli_default.dup
          h.each_with_index do |field, k|
            case field.downcase
            when *%w[query ignore-dup get-metadata only-metadata]
              argv_i << "--#{field.downcase}" if r[k].downcase == 'true'
            when *%w[project file verbose help debug]
              raise "Unsupported header: #{field}"
            else
              argv_i += ["--#{field.downcase}", r[k]]
            end
          end
          sub_cli = MiGA::Cli.new(argv_i)
          sub_cli.defaults = cli.data
          sub_cli.action.parse_cli
          glob << sub_cli
        end
      end
    end
    glob
  end

  def create_remote_dataset(sub_cli, p)
    sub_cli.ensure_par(dataset: '-D', ids: '-I')
    unless sub_cli[:api_key].nil?
      if sub_cli[:universe] == :web && sub_cli[:db] == :assembly_gz
        ENV['NCBI_API_KEY'] = sub_cli[:api_key]
      end

      var_space = sub_cli[:universe].to_s.upcase
      ENV["#{var_space}_API_KEY"] = sub_cli[:api_key]
    end

    sub_cli.say "Dataset: #{sub_cli[:dataset]}"
    if sub_cli[:ignore_dup] && !sub_cli[:get_md]
      return if Dataset.exist?(p, sub_cli[:dataset])
    end

    sub_cli.say 'Locating remote dataset'
    RemoteDataset.new(sub_cli[:ids], sub_cli[:db], sub_cli[:universe])
  end

  def update_metadata(sub_cli, p, rd)
    sub_cli.say 'Updating dataset'
    d = p.dataset(sub_cli[:dataset])
    return if d.nil?

    md = sub_cli.add_metadata(d).metadata.data
    rd.update_metadata(d, md)
  end

  def create_dataset(sub_cli, p, rd)
    sub_cli.say 'Creating dataset'
    if Dataset.exist?(p, sub_cli[:dataset])
      raise "Dataset already exists: #{sub_cli[:dataset]}"
    end

    dummy_d = Dataset.new(p, sub_cli[:dataset])
    md = sub_cli.add_metadata(dummy_d).metadata.data
    md[:metadata_only] = true if cli[:only_md]
    dummy_d.remove!
    rd.save_to(p, sub_cli[:dataset], !sub_cli[:query], md)
    p.add_dataset(sub_cli[:dataset])
  end
end
