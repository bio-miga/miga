# frozen_string_literal: true

require 'miga/cli/action'

class MiGA::Cli::Action::NcbiGet < MiGA::Cli::Action
  require 'miga/cli/action/download/ncbi'
  include MiGA::Cli::Action::Download::Ncbi

  def parse_cli
    cli.defaults = {
      query: false, unlink: false,
      reference: false, legacy_name: false,
      complete: false, chromosome: false,
      scaffold: false, contig: false, add_version: true, dry: false,
      get_md: false, only_md: false, save_every: 1
    }
    cli.parse do |opt|
      cli.opt_object(opt, [:project])
      opt.on(
        '-T', '--taxon STRING',
        '(Mandatory) Taxon name (e.g., a species binomial)'
      ) { |v| cli[:taxon] = v }
      opt.on(
        '--max INT', Integer,
        'Maximum number of datasets to download (by default: unlimited)'
      ) { |v| cli[:max_datasets] = v }
      opt.on(
        '-m', '--metadata STRING',
        'Metadata as key-value pairs separated by = and delimited by comma',
        'Values are saved as strings except for booleans (true / false) or nil'
      ) { |v| cli[:metadata] = v }
      cli_task_flags(opt)
      cli_name_modifiers(opt)
      cli_filters(opt)
      cli_save_actions(opt)
      opt.on(
        '--api-key STRING',
        'NCBI API key'
      ) { |v| ENV['NCBI_API_KEY'] = v }
    end
  end

  alias :generic_perform :perform

end
