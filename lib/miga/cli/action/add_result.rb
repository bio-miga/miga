# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::AddResult < MiGA::Cli::Action
  def parse_cli
    cli.defaults = { force: false, stdin_versions: false }
    cli.parse do |opt|
      cli.opt_object(opt, [:project, :dataset_opt, :result])
      opt.on(
        '-f', '--force',
        'Force re-indexing of the result even if it\'s already registered'
      ) { |v| cli[:force] = v }
      opt.on(
        '--stdin-versions',
        'Read Software versions from STDIN'
      ) { |v| cli[:stdin_versions] = v }
    end
  end

  def perform
    cli.ensure_par(result: '-r')
    obj = cli.load_project_or_dataset
    cli.say "Registering result: #{cli[:result]}"
    r = obj.add_result(cli[:result], true, force: cli[:force])
    raise 'Cannot add result, incomplete expected files' if r.nil?

    # Add Software version data
    if cli[:stdin_versions]
      versions = {}
      sw = nil
      $stdin.each do |ln|
        ln = ln.chomp.strip
        if ln =~ /^=> (.*)/
          sw = $1
          versions[sw] = ''
        else
          versions[sw] += ln
        end
      end
      r.add_versions(versions)
      r.save
    end
  end
end
