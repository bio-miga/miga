# frozen_string_literal: true

require 'miga/cli/action'

class MiGA::Cli::Action::SeqcodeGet < MiGA::Cli::Action
  require 'miga/cli/action/download/seqcode'
  include MiGA::Cli::Action::Download::Seqcode

  def parse_cli
    cli.defaults = {
      query: false, unlink: false,
      reference: false, add_version: true, dry: false,
      get_md: false, only_md: false, save_every: 1
    }
    cli.parse do |opt|
      cli.opt_object(opt, [:project])
      cli_base_flags(opt)
      opt.on(
        '--ncbi-taxonomy',
        'Retrieve NCBI taxonomy instead of SeqCode taxonomy'
      ) { |v| cli[:get_ncbi_taxonomy] = v }
      cli_task_flags(opt)
      cli_name_modifiers(opt)
      cli_filters(opt)
      cli_save_actions(opt)
      opt.on(
        '--ncbi-api-key STRING',
        'NCBI API key'
      ) { |v| ENV['NCBI_API_KEY'] = v }
    end
  end

  def perform
    generic_perform
  end

end
