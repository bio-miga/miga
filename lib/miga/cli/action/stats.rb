# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Stats < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { try_load: false }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt, :result])
      opt.on(
        '--key STRING',
        'Return only the value of the requested key'
      ) { |v| cli[:key] = v }
      opt.on(
        '--compute-and-save',
        'Compute and save the statistics'
      ) { |v| cli[:compute] = v }
      opt.on(
        '--try-load',
        'Check if stat exists instead of computing on --compute-and-save'
      ) { |v| cli[:try_load] = v }
      opt.on(
        '--ignore-empty',
        'If the result does not exist, exit without throwing exceptions'
      ) { |v| cli[:ignore_result_empty] = v }
    end
  end

  def perform
    r = cli.load_result or return

    cli[:compute] = false if cli[:try_load] && !r[:stats]&.empty?

    if cli[:compute]
      cli.say 'Computing statistics'
      r.compute_stats
    end

    if cli[:key].nil?
      r[:stats].each do |k, v|
        k_n = k.to_s.unmiga_name.sub(/^./, &:upcase)
        cli.puts "#{k_n}: #{v.is_a?(Array) ? v.join(' ') : v}"
      end
    else
      v = r[:stats][cli[:key].downcase.miga_name.to_sym]
      puts v.is_a?(Array) ? v.first : v
    end
  end
end
