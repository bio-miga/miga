# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'miga/remote_dataset'
require 'csv'

class MiGA::Cli::Action::NcbiGet < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { query: false, unlink: false,
      reference: false, legacy_name: false,
      complete: false, chromosome: false,
      scaffold: false, contig: false, add_version: true, dry: false,
      get_md: false, only_md: false, save_every: 1 }
    cli.parse do |opt|
      cli.opt_object(opt, [:project])
      opt.on(
        '-T', '--taxon STRING',
        '(Mandatory unless --reference) Taxon name (e.g., a species binomial)'
      ) { |v| cli[:taxon] = v }
      cli.opt_flag(
        opt, 'reference',
        'Download all reference genomes (ignore any other status)'
      )
      cli.opt_flag(opt, 'complete', 'Download complete genomes')
      cli.opt_flag(opt, 'chromosome', 'Download complete chromosomes')
      cli.opt_flag(opt, 'scaffold', 'Download genomes in scaffolds')
      cli.opt_flag(opt, 'contig', 'Download genomes in contigs')
      opt.on(
        '--all',
        'Download all genomes (in any status)'
      ) do
        cli[:complete] = true
        cli[:chromosome] = true
        cli[:scaffold] = true
        cli[:contig] = true
      end
      opt.on(
        '--no-version-name',
        'Do not add sequence version to the dataset name',
        'Only affects --complete and --chromosome'
      ) { |v| cli[:add_version] = v }
      cli.opt_flag(
        opt, 'legacy-name',
        'Use dataset names based on chromosome entries instead of assembly',
        :legacy_name
      )
      opt.on(
        '--blacklist PATH',
        'A file with dataset names to blacklist'
      ) { |v| cli[:blacklist] = v }
      cli.opt_flag(opt, 'dry', 'Do not download or save the datasets')
      opt.on(
        '--ignore-until STRING',
        'Ignores all datasets until a name is found (useful for large reruns)'
      ) { |v| cli[:ignore_until] = v }
      cli.opt_flag(opt, 'get-metadata',
        'Only download and update metadata for existing datasets', :get_md)
      cli.opt_flag(
        opt, 'only-metadata',
        'Create datasets without input data but retrieve all metadata',
        :only_md)
      opt.on(
        '--save-every INT', Integer,
        'Save project every this many downloaded datasets',
        'If zero, it saves the project only once upon completion',
        "By default: #{cli[:save_every]}"
      ) { |v| cli[:save_every] = v }
      opt.on(
        '-q', '--query',
        'Register the datasets as queries, not reference datasets'
      ) { |v| cli[:query] = v }
      opt.on(
        '-u', '--unlink',
        'Unlink all datasets in the project missing from the download list'
      ) { |v| cli[:unlink] = v }
      opt.on(
        '-R', '--remote-list PATH',
        'Path to an output file with the list of all datasets listed remotely'
      ) { |v| cli[:remote_list] = v }
      opt.on(
        '--api-key STRING',
        'NCBI API key'
      ) { |v| ENV['NCBI_API_KEY'] = v }
    end
  end

  def perform
    sanitize_cli
    p = cli.load_project
    ds = download_remote_list
    ds = discard_blacklisted(ds)
    d, downloaded = download_entries(ds, p)

    # Finalize
    cli.say "Datasets listed: #{d.size}"
    act = cli[:dry] ? 'to download' : 'downloaded'
    cli.say "Datasets #{act}: #{downloaded}"
    unless cli[:remote_list].nil?
      File.open(cli[:remote_list], 'w') do |fh|
        d.each { |i| fh.puts i }
      end
    end
    return unless cli[:unlink]
    unlink = p.dataset_names - d
    unlink.each { |i| p.unlink_dataset(i).remove! }
    cli.say "Datasets unlinked: #{unlink.size}"
  end

  private

  def sanitize_cli
    cli.ensure_par(taxon: '-T') unless cli[:reference]
    tasks = %w[reference complete chromosome scaffold contig]
    unless tasks.any? { |i| cli[i.to_sym] }
      raise 'No action requested: pick at least one type of genome'
    end
    cli[:save_every] = 1 if cli[:dry]
  end

  def download_remote_list
    cli.say 'Downloading genome list'
    ds = {}
    url = remote_list_url
    doc = RemoteDataset.download_url(url)
    CSV.parse(doc, headers: true).each do |r|
      asm = r['assembly']
      next if asm.nil? || asm.empty? || asm == '-'
      next unless r['ftp_path_genbank']

      # Get replicons
      rep = nil
      unless r['replicons'].nil?
        rep = r['replicons'].split('; ').
              map { |i| i.gsub(/.*:/, '') }.
              map { |i| i.gsub(/\/.*/, '') }
      end

      # Set name
      if cli[:legacy_name] && cli[:reference]
        n = r['#organism'].miga_name
      else
        if cli[:legacy_name] && ['Complete', ' Chromosome'].include?(r['level'])
          acc = rep.nil? ? '' : rep.first
        else
          acc = asm
        end
        acc.gsub!(/\.\d+\Z/, '') unless cli[:add_version]
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
      unless r['release_date'].nil?
        ds[n][:md][:release_date] = Time.parse(r['release_date']).to_s
      end
    end
    ds
  end

  def remote_list_url
    url_base = 'https://www.ncbi.nlm.nih.gov/genomes/solr2txt.cgi?'
    url_param = {
      q: '[display()].' \
        'from(GenomeAssemblies).' \
        'usingschema(/schema/GenomeAssemblies).' \
        'matching(tab==["Prokaryotes"] and q=="' \
          "#{cli[:taxon].tr('"', "'")}\"",
      fields: 'organism|organism,assembly|assembly,replicons|replicons,' \
        'level|level,ftp_path_genbank|ftp_path_genbank,' \
        'release_date|release_date,strain|strain',
      nolimit: 'on'
    }
    if cli[:reference]
      url_param[:q] += ' and refseq_category==["representative"]'
    else
      status = {
        complete: 'Complete',
        chromosome: ' Chromosome', # <- The leading space is *VERY* important!
        scaffold: 'Scaffold',
        contig: 'Contig'
      }.map { |k, v| '"' + v + '"' if cli[k] }.compact.join(',')
      url_param[:q] += ' and level==[' + status + ']'
    end
    url_param[:q] += ')'
    url_base + URI.encode_www_form(url_param)
  end

  def discard_blacklisted(ds)
    unless cli[:blacklist].nil?
      cli.say "Discarding datasets in #{cli[:blacklist]}"
      File.readlines(cli[:blacklist]).
        select { |i| i !~ /^#/ }.map(&:chomp).each { |i| ds.delete i }
    end
    ds
  end

  def download_entries(ds, p)
    cli.say "Downloading #{ds.size} " + (ds.size == 1 ? 'entry' : 'entries')
    p.do_not_save = true if cli[:save_every] != 1
    ignore = !cli[:ignore_until].nil?
    downloaded = 0
    d = []
    ds.each do |name, body|
      d << name
      cli.puts name
      ignore = false if ignore && name == cli[:ignore_until]
      next if ignore
      next if p.dataset(name).nil? == cli[:get_md]
      downloaded += 1
      next if cli[:dry]
      cli.say '  Locating remote dataset'
      body[:md][:metadata_only] = true if cli[:only_md]
      rd = RemoteDataset.new(body[:ids], body[:db], body[:universe])
      if cli[:get_md]
        cli.say '  Updating dataset'
        rd.update_metadata(p.dataset(name), body[:md])
      else
        cli.say '  Creating dataset'
        rd.save_to(p, name, !cli[:query], body[:md])
        p.add_dataset(name)
      end
      p.save! if cli[:save_every] > 1 && (downloaded % cli[:save_every]).zero?
    end
    p.do_not_save = false
    p.save! if cli[:save_every] != 1
    [d, downloaded]
  end
end
