# frozen_string_literal: true

require 'miga/cli/action/download/base'

##
# Helper module including download functions for the seqcode_get action
module MiGA::Cli::Action::Download::Seqcode
  include MiGA::Cli::Action::Download::Base

  def cli_task_flags(_opt)
  end

  def cli_name_modifiers(opt)
    opt.on(
      '--no-version-name',
      'Do not add sequence version to the dataset name'
    ) { |v| cli[:add_version] = v }
  end

  def sanitize_cli
    cli[:save_every] = 1 if cli[:dry]
  end

  def remote_list
    cli.say 'Downloading genome list'
    current_page = 1
    total_pages  = 1
    ds = {}

    while current_page <= total_pages
      json = MiGA::RemoteDataset.download(
        :seqcode, :'type-genomes', nil, :json, nil, page: current_page
      )
      doc = MiGA::Json.parse(json, contents: true)
      current_page = doc[:current_page] + 1
      total_pages  = doc[:total_pages]

      doc[:values].each do |name|
        next unless name[:type_material]
        acc = name[:type_material].values.first
        db  = name[:type_material].keys.first
        next unless %i[assembly nuccore].include?(db) # No INSDC genome, ignore

        classif = name[:classification] || {}
        tax = MiGA::Taxonomy.new(Hash[classif.map { |i| [i[:rank], i[:name]] }])
        tax << { 'ns' => 'seqcode', name[:rank] => name[:name] }
        d = {
          ids: [acc], db: db, universe: :seqcode,
          md: {
            type: :genome, tax: tax, is_type: true,
            type_rel: 'SeqCode type genome',
            seqcode_url: "https://seqco.de/i:#{name[:id]}"
          }
        }
        d[:md][:get_ncbi_taxonomy] = true if cli[:get_ncbi_taxonomy]
        ds[remote_row_name(tax, db, acc)] = d
      end
    end
    ds
  end

  def remote_row_name(tax, db, asm)
    acc = asm.to_s
    acc.gsub!(/\.\d+\Z/, '') unless cli[:add_version]
    db_short = { assembly: 'asm', nuccore: 'gb' }[db]
    "#{tax.lowest[1]}_#{db_short}_#{acc}".miga_name
  end
end
