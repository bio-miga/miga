# @package MiGA
# @license Artistic-2.0

##
# Helper module for workflows
module MiGA::Cli::Action::Wf
  def opts_for_wf(opt, files_desc)
    opt.separator ''
    opt.separator "    FILES...: #{files_desc}"
    opt.separator ''
    opt.separator 'General Options'
    opt.on(
      '--daemon PATH',
      'Use custom daemon configuration in JSON format'
      ){ |v| cli[:daemon_json] = v }
  end

  def create_project(stage)
    ensure_par(out_dir: '-o')
    p = MiGA::Project.new(cli[:out_dir])
    cli.files.each do |f|
      m = cli[:regexp].match(f)
      raise "Cannot extract name from file: #{f}" if m.nil? or m[1].nil?
      name = m[1].miga_name
      # TODO: Copy files and add to project (see `miga add`)
    end
  end

end
