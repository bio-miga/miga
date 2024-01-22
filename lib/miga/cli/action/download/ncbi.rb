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
    # For backwards compatibility
    cli.opt_flag(opt, 'legacy-name', '::HIDE::', :legacy_name)
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
    list  = {}
    query = remote_list_query
    loop do
      # Query the remote collection
      page = MiGA::Json.parse(
        MiGA::RemoteDataset.download(:ncbi_datasets, :genome, query, :json),
        contents: true
      )
      break unless page&.any? && page[:reports]&.any?

      # Process reports in this page
      list.merge!(parse_reports_as_datasets(page[:reports]))

      # Next page
      break unless page[:next_page_token]
      query[:page_token] = page[:next_page_token]
    end
    list
  end
  
  def parse_reports_as_datasets(reports)
    ds = {}
    reports.each do |r|
      asm = r[:accession]
      next if asm.nil? || asm.empty? || asm == '-'

      # Register for download
      n = remote_report_name(r, asm)
      ds[n] = {
        ids: [asm], db: :assembly, universe: :ncbi,
        md: {
          type: :genome, ncbi_asm: asm, strain: r.dig(:organism, :infraspecific_names, :strain)
        }
      }
      date = r.dig(:assembly_info, :release_date)
      ds[n][:md][:release_date] = Time.parse(date).to_s if date
      ds[n][:md][:ncbi_dataset] = r
    end
    ds
  end

  def remote_report_name(r, asm)
    acc = "#{asm}"
    acc.gsub!(/\.\d+\Z/, '') unless cli[:add_version]
    org = r.dig(:organism, :organism_name)
    acc = "#{org}_#{acc}" if org
    acc.miga_name
  end

  def remote_list_query
    q = { taxons: [cli[:taxon]], filters: {} }
    if cli[:reference]
      q[:filters][:reference_only] = true
    else
      q[:assembly_level] = {
        contig: 'contig',
        scaffold: 'scaffold',
        chromosome: 'chromosome',
        complete: 'complete_genome'
      }.map { |k, v| '"' + v + '"' if cli[k] }.compact
    end
    q
  end
end
