# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'

class MiGA::Cli::Action::Cmd < MiGA::Cli::Action
  def parse_cli
    cli.expect_files = true
    cli.files_label  = 'CMD'
    cli.defaults = {
      raise: false, return: :status, source: :miga_env,
      stdout: nil, stderr: nil, dry: false, show_cmd: false,
      err2out: false
    }
    cli.parse do |opt|
      opt.separator 'To separate command flags from MiGA flags, use --:'
      opt.separator 'miga cmd --verbose -- rbm.rb --version'
      opt.separator ''
      opt.separator 'To run the command as is (no escaping), use single-quotes:'
      opt.separator 'miga cmd \'echo $MIGA\''
      opt.separator ''
      opt.on(
        '-o', '--stdout FILE',
        'Save STDOUT to this file instead of displaying it'
      ) { |v| cli[:stdout] = v }
      opt.on(
        '-e', '--stderr FILE',
        'Save STDERR to this file instead of displaying it'
      ) { |v| cli[:stderr] = v }
      opt.on(
        '--err2out',
        'Combine STDERR and STDOUT into one single channel (STDOUT)'
      ) { |v| cli[:err2out] = v }
      opt.on(
        '--show-cmd',
        'Show exact command being launched before running it'
      ) { |v| cli[:show_cmd] = v }
      opt.on(
        '--dry',
        'Prepare the command but stop short of executing it',
        'Useful in combination with --show-cmd; it always exits with code 1'
      ) { |v| cli[:dry] = v }
    end
  end

  def perform
    cli.files
    cli.say 'Running command:'
    cmd = cli.files.size == 1 ? cli.files[0] : cli.files
    cli.say cmd
    status = MiGA::MiGA.run_cmd(cmd, cli.to_h)
    cli.say 'Exit status: %s' % status
    unless status&.success?
      exit(status.nil? ? 1 : status.exitstatus)
    end
  end
end
