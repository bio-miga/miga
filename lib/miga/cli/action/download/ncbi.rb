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
    opt.on('--all', 'Download all genomes (in any status)') do
      cli[:complete] = true
      cli[:chromosome] = true
      cli[:scaffold] = true
      cli[:contig] = true
    end
    opt.on('--ncbi-list-json STRING', '::HIDE::') do |v|
      cli[:ncbi_list_json] = v
    end
  end

  def cli_name_modifiers(opt)
    opt.on(
      '--no-version-name',
      'Do not add sequence version to the dataset name',
      'Only affects --complete and --chromosome'
    ) { |v| cli[:add_version] = v }
    # For backwards compatibility
    opt.on('--legacy-name', '::HIDE::') do
      warn 'Deprecated flag --legacy-name ignored'
    end
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
    if cli[:ncbi_list_json] && File.size?(cli[:ncbi_list_json])
      return read_ncbi_list_json(cli[:ncbi_list_json])
    end

    cli.say "Obtaining remote list of datasets"
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
      cli.advance('Datasets:', list.size, page[:total_count])
      break unless page[:next_page_token]
      query[:page_token] = page[:next_page_token]
    end
    cli.say

    write_ncbi_list_json(cli[:ncbi_list_json], list) if cli[:ncbi_list_json]
    list
  end

  def read_ncbi_list_json(file)
    cli.say "Reusing remote list: #{file}"
    list = {}
    n_tot = nil
    File.open(file, 'r') do |fh|
      n_tot = fh.gets.chomp.sub(/^# /, '').to_i
      fh.each_with_index do |ln, k|
        row = ln.chomp.split("\t", 2)
        list[row[0]] = MiGA::Json.parse(row[1], contents: true)
        cli.advance('Lines:', k, n_tot)
      end
      cli.say
    end
    return list
  end

  def write_ncbi_list_json(file, list)
    cli.say "Saving remote list: #{file}"
    File.open(file, 'w') do |fh|
      fh.puts('# %i' % list.size)
      kk = 0
      list.each do |k, v|
        fh.puts([k, MiGA::Json.generate_fast(v)].join("\t"))
        cli.advance('Datasets:', kk += 1, list.size)
      end
      cli.say
    end
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
          type: :genome, ncbi_asm: asm,
          strain: r.dig(:organism, :infraspecific_names, :strain)
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
