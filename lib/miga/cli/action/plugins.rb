# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Plugins < MiGA::Cli::Action

  def parse_cli
    cli.parse do |opt|
      cli.opt_object(opt, [:project])
      opt.on(
        '--install PATH',
        'Install the specified plugin in the project'
        ){ |v| cli[:install] = v }
      opt.on(
        '--uninstall PATH',
        'Uninstall the specified plugin from the project'
        ){ |v| cli[:uninstall] = v }
    end
  end

  def perform
    p = cli.load_project
    p.install_plugin(cli[:install]) unless cli[:install].nil?
    p.uninstall_plugin(cli[:uninstall]) unless cli[:uninstall].nil?
    p.plugins.each { |i| cli.puts i }
  end
end
