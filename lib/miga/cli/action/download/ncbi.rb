# frozen_string_literal: true

require 'miga/cli/action/download/base'
require 'csv'

##
# Helper module including download functions for the ncbi_get action
module MiGA::Cli::Action::Download::Ncbi
  include MiGA::Cli::Action::Download::Base

  def cli_task_flags(opt)
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
  end

  def cli_name_modifiers(opt)
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
  end

  def sanitize_cli
    cli.ensure_par(taxon: '-T')
    tasks = %w[reference complete chromosome scaffold contig]
    unless tasks.any? { |i| cli[i.to_sym] }
      raise 'No action requested: pick at least one type of genome'
    end

    cli[:save_every] = 1 if cli[:dry]
  end

  def remote_list
    doc =
      if cli[:ncbi_table_file]
        cli.say 'Reading genome list from file'
        File.open(cli[:ncbi_table_file], 'r')
      else
        cli.say 'Downloading genome list'
        url = remote_list_url
        MiGA::RemoteDataset.download_url(url)
      end
    ds = parse_csv_as_datasets(doc)
    doc.close if cli[:ncbi_table_file]
    ds
  end
  
  def parse_csv_as_datasets(doc)
    ds = {}
    CSV.parse(doc, headers: true).each do |r|
      asm = r['assembly']
      next if asm.nil? || asm.empty? || asm == '-'

      rep = remote_row_replicons(r)
      n = remote_row_name(r, rep, asm)

      # Register for download
      ds[n] = {
        ids: [asm], db: :assembly, universe: :ncbi,
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

  def remote_row_replicons(r)
    return if r['replicons'].nil?

    r['replicons']
      .split('; ')
      .map { |i| i.gsub(/.*:/, '') }
      .map { |i| i.gsub(%r{/.*}, '') }
  end

  def remote_row_name(r, rep, asm)
    return r['#organism'].miga_name if cli[:legacy_name] && cli[:reference]

    if cli[:legacy_name] && ['Complete', ' Chromosome'].include?(r['level'])
      acc = rep.nil? ? '' : rep.first
    else
      acc = asm
    end
    acc.gsub!(/\.\d+\Z/, '') unless cli[:add_version]
    "#{r['#organism']}_#{acc}".miga_name
  end

  def remote_list_url
    url_base = 'https://www.ncbi.nlm.nih.gov/genomes/solr2txt.cgi?'
    url_param = {
      q: '[display()].' \
        'from(GenomeAssemblies).' \
        'usingschema(/schema/GenomeAssemblies).' \
        'matching(tab==["Prokaryotes"] and q=="' \
          "#{cli[:taxon]&.tr('"', "'")}\"",
      fields: 'organism|organism,assembly|assembly,replicons|replicons,' \
        'level|level,release_date|release_date,strain|strain',
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
end
