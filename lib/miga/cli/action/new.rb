# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::New < MiGA::Cli::Action
  def parse_cli
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :project_type_req])
      opt.on(
        '-n', '--name STRING',
        'Name of the project'
      ) { |v| cli[:name] = v }
      opt.on(
        '-d', '--description STRING',
        'Description of the project'
      ) { |v| cli[:description] = v }
      opt.on(
        '-c', '--comments STRING',
        'Comments on the project'
      ) { |v| cli[:comments] = v }
      opt.on(
        '--fast',
        'Use faster identity engines (Diamond-AAI and FastANI)',
        'Equivalent to: -m aai_p=diamond,ani_p=fastani'
      ) { |v| cli[:fast] = v }
      opt.on(
        '--sensitive',
        'Use more sensitive identity engines (BLAST+)',
        'Equivalent to: -m aai_p=blast+,ani_p=blast+'
      ) { |v| cli[:sensitive] = v }
      opt.on(
        '-m', '--metadata STRING',
        'Metadata as key-value pairs separated by = and delimited by comma',
        'Values are saved as strings except for booleans (true / false) or nil'
      ) { |v| cli[:metadata] = v }
      opt.on(
        '--ignore-init',
        'Ignore checks for MiGA initialization',
        'This can be used to create projects that are processed elsewhere'
      ) { |v| cli[:ignore_init] = v }
    end
  end

  def perform
    cli.ensure_type(MiGA::Project)
    cli.ensure_par(project: '-P')
    if !cli[:ignore_init] && !MiGA::MiGA.initialized?
      raise 'MiGA has not been initialized, please use "miga init" first'
    end
    cli.say "Creating project: #{cli[:project]}"
    raise 'Project already exists, aborting' if Project.exist?(cli[:project])

    p = Project.new(cli[:project], false)
    p = cli.add_metadata(p)

    if cli[:sensitive]
      p.set_option(:aai_p, 'blast+')
      p.set_option(:ani_p, 'blast+')
    elsif cli[:fast]
      p.set_option(:aai_p, 'diamond')
      p.set_option(:ani_p, 'fastani')
    end
  end
end
