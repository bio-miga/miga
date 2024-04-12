# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Find < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { add: false, ref: true }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_type])
      opt.on(
        '-a', '--add',
        'Register the datasets found',
        'By default, only lists them (dry run)'
      ) { |v| cli[:add] = v }
      opt.on(
        '-q', '--query',
        'Register datasets as query'
      ) { |v| cli[:ref] = !v }
      opt.on(
        '-u', '--user STRING',
        'Owner of the dataset.'
      ) { |v| cli[:user] = v }
      opt.on(
        '-m', '--metadata STRING',
        'Metadata as key-value pairs separated by = and delimited by comma',
        'Values are saved as strings except for booleans (true / false) or nil'
      ) { |v| cli[:metadata] = v }
    end
  end

  def perform
    p = cli.load_project
    ud = p.unregistered_datasets
    ud.each do |dn|
      cli.puts dn
      if cli[:add]
        cli.say "Registering: #{dn}"
        d = Dataset.new(p, dn, cli[:ref])
        cli.add_metadata(d)
        p.add_dataset(dn)
        res = d.first_preprocessing(true)
        cli.say "- #{res}"
      end
    end
  end
end
