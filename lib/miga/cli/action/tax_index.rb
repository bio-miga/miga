# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'miga/tax_index'

class MiGA::Cli::Action::TaxIndex < MiGA::Cli::Action

  def parse_cli
    cli.defaults = {format: :json}
    cli.parse do |opt|
      cli.opt_object(opt, [:project])
      opt.on(
        '-i', '--index PATH',
        '(Mandatory) File to create with the index'
        ){ |v| cli[:index] = v }
      opt.on(
        '-f', '--format STRING',
        "Format of the index file, by default: #{cli[:format]}",
        'Supported: json, tab.'
        ){ |v| cli[:format] = v.downcase.to_sym }
      cli.opt_filter_datasets(opt)
    end
  end

  def perform
    cli.ensure_par(index: '-i')
    ds = cli.load_and_filter_datasets

    cli.say 'Indexing taxonomy'
    tax_index = MiGA::TaxIndex.new
    ds.each_with_index do |d, i|
      cli.advance('Datasets:', i, ds.size, false)
      tax_index << d unless d.metadata[:tax].nil?
    end
    cli.say ''

    cli.say 'Saving index'
    File.open(cli[:index], 'w') do |fh|
      case cli[:format]
      when :json
        fh.print tax_index.to_json
      when :tab
        fh.print tax_index.to_tab
      else
        raise "Unsupported output format: #{cli[:format]}"
      end
    end
  end
end
