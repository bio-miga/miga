# frozen_string_literal: true

require 'miga/cli/action'

class MiGA::Cli::Action::NcbiGet < MiGA::Cli::Action
  require 'miga/cli/action/download/ncbi'
  include MiGA::Cli::Action::Download::Ncbi

  def parse_cli
    cli.defaults = {
      query: false, unlink: false, reference: false,
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
      cli_base_flags(opt)
      cli_task_flags(opt)
      cli_name_modifiers(opt)
      cli_filters(opt)
      cli_save_actions(opt)
      opt.on('--api-key STRING', '::HIDE::') do |v|
        warn "The use of --api-key is deprecated, please use --ncbi-api-key"
        ENV['NCBI_API_KEY'] = v
      end
      opt.on('--ncbi-api-key STRING', 'NCBI API key') do |v|
        ENV['NCBI_API_KEY'] = v
      end
    end
  end

  def perform
    generic_perform
  end
end
