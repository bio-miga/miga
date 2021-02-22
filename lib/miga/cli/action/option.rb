# frozen_string_literal: true

require 'miga/cli/action'

##
# CLI: `miga option`
class MiGA::Cli::Action::Option < MiGA::Cli::Action
  def parse_cli
    cli.parse do |opt|
      cli.opt_object(opt, %i[project dataset_opt])
      opt.on(
        '-k', '--key STRING',
        'Option name to get or set (by default, all options are printed)'
      ) { |v| cli[:key] = v }
      opt.on(
        '--value STRING',
        'Value of the option to set (by default, option value is not changed)',
        'Recognized tokens: nil, true, false'
      ) { |v| cli[:value] = v }
      opt.on(
        '--about',
        'Print additional information about the values supported by this option'
      ) { |v| cli[:about] = v }
      opt.on(
        '-o', '--output PATH',
        'Create output file instead of returning to STDOUT'
      ) { |v| cli[:output] = v }
    end
  end

  def perform
    unless cli[:value].nil? && !cli[:about]
      cli.ensure_par(
        { key: '-k' },
        '%<name>s is mandatory when --value / --about are set: provide %<flag>s'
      )
    end
    obj = cli.load_project_or_dataset
    io = cli[:output].nil? ? $stdout : File.open(cli[:output], 'w')
    if cli[:key].nil?
      cli.table(%w[Key Value], obj.all_options, io)
    elsif cli[:about]
      opt = obj.assert_has_option(cli[:key])
      title = "#{cli[:key]}: #{opt[:desc]}"
      io.puts title
      io.puts '-' * title.length
      opt.each do |k, v|
        v = v[obj] if v.is_a? Proc
        io.puts "#{k.to_s.capitalize}: #{v}" unless k == :desc
      end
    else
      obj.set_option(cli[:key], cli[:value], true) unless cli[:value].nil?
      io.puts obj.option(cli[:key])
    end
    io.close unless cli[:output].nil?
  end
end
