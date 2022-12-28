# frozen_string_literal: true

require 'miga/cli/action/download/base'

##
# Helper module including download functions for the gtdb_get action
module MiGA::Cli::Action::Download::Gtdb
  include MiGA::Cli::Action::Download::Base

  def cli_task_flags(opt)
    cli.opt_flag(
      opt, 'reference',
      'Download only reference genomes. By default: download all'
    )
  end

  def cli_name_modifiers(opt)
    opt.on(
      '--no-version-name',
      'Do not add sequence version to the dataset name'
    ) { |v| cli[:add_version] = v }
  end

  def sanitize_cli
    cli.ensure_par(taxon: '-T')
    cli[:save_every] = 1 if cli[:dry]
  end

  def remote_list
    cli.say 'Downloading genome list'
    ds = {}
    extra = ['sp_reps_only=' + cli[:reference].to_s]
    json = MiGA::RemoteDataset.download(
      :gtdb, :taxon, cli[:taxon], :genomes, nil, extra
    )
    doc = MiGA::Json.parse(json, contents: true)

    Hash[
      doc.map do |acc|
        [
          remote_row_name(acc),
          {
            ids: [acc], db: :assembly, universe: :gtdb,
            md: { type: :genome, gtdb_assembly: acc }
          }
        ]
      end
    ]
  end

  def remote_row_name(asm)
    acc = "#{asm}"
    acc.gsub!(/\.\d+\Z/, '') unless cli[:add_version]
    acc.miga_name
  end
end
