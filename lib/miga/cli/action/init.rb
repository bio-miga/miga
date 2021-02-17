# frozen_string_literal: true

require 'miga/cli/action'
require 'shellwords'

class MiGA::Cli::Action::Init < MiGA::Cli::Action
  require 'miga/cli/action/init/daemon_helper'
  require 'miga/cli/action/init/files_helper'
  include MiGA::Cli::Action::Init::DaemonHelper
  include MiGA::Cli::Action::Init::FilesHelper

  def parse_cli
    cli.interactive = true
    cli.defaults = {
      mytaxa: nil,
      rdp: nil,
      config: File.join(ENV['MIGA_HOME'], '.miga_modules'),
      ask: false,
      auto: false,
      dtype: :bash
    }
    cli.parse do |opt|
      opt.on(
        '-c', '--config PATH',
        'Path to the Bash configuration file',
        "By default: #{cli[:config]}"
      ) { |v| cli[:config] = v }
      opt.on(
        '--[no-]mytaxa',
        'Should I try setting up MyTaxa and its dependencies?',
        'By default: interactive (true if --auto)'
      ) { |v| cli[:mytaxa] = v }
      opt.on(
        '--[no-]rdp',
        'Should I try setting up the RDP classifier?',
        'By default: interactive (true if --auto)'
      ) { |v| cli[:rdp] = v }
      opt.on(
        '--daemon-type STRING',
        'Type of daemon launcher, one of: bash, ssh, qsub, msub, slurm',
        "By default: interactive (#{cli[:dtype]} if --auto)"
      ) { |v| cli[:dtype] = v.to_sym }
      opt.on(
        '--ask-all',
        'Ask for the location of all software',
        'By default, only the locations missing in PATH are requested'
      ) { |v| cli[:ask] = v }
    end
  end

  def perform
    cli.puts <<~BANNER
      ===[ Welcome to MiGA, the Microbial Genome Atlas ]===

      I'm the initialization script, and I'll sniff around your computer to
      make sure you have all the requirements for MiGA data processing.

    BANNER
    list_requirements
    rc_fh = open_rc_file
    check_configuration_script(rc_fh)
    paths = check_software_requirements(rc_fh)
    check_additional_files(paths)
    check_r_packages(paths)
    check_ruby_gems(paths)
    check_python_libraries(paths)
    configure_daemon
    close_rc_file(rc_fh)
    cli.puts 'Configuration complete. MiGA is ready to work!'
    cli.puts ''
  end

  def empty_action
  end

  def run_cmd(cli, cmd)
    `. "#{cli[:config]}" && #{cmd}`
  end

  def run_r_cmd(cli, paths, cmd)
    run_cmd(
      cli,
      "echo #{cmd.shellescape} | #{paths['R'].shellescape} --vanilla -q 2>&1"
    )
  end

  def test_r_package(cli, paths, pkg)
    run_r_cmd(cli, paths, "library('#{pkg}')")
    $?.success?
  end

  def install_r_package(cli, paths, pkg)
    r_cmd = "install.packages('#{pkg}', repos='http://cran.rstudio.com/')"
    run_r_cmd(cli, paths, r_cmd)
  end

  def test_ruby_gem(cli, paths, pkg)
    run_cmd(
      cli,
      "#{paths['ruby'].shellescape} -r #{pkg.shellescape} -e '' 2>/dev/null"
    )
    $?.success?
  end

  def install_ruby_gem(cli, paths, pkg)
    # This hackey mess is meant to ensure the test and installation are done
    # on the configuration Ruby, not on the Ruby currently executing the
    # init action
    gem_cmd = "Gem::GemRunner.new.run %w(install --user #{pkg})"
    run_cmd(
      cli,
      "#{paths['ruby'].shellescape} \
        -r rubygems -r rubygems/gem_runner \
        -e #{gem_cmd.shellescape} 2>&1"
    )
  end

  def test_python_library(cli, paths, pkg)
    run_cmd(
      cli, "#{paths['python3'].shellescape} -c 'import #{pkg}' 2>/dev/null"
    )
    $?.success?
  end

  def install_python_library(cli, paths, pkg)
    run_cmd(
      cli,
      "#{paths['python3'].shellescape} -m pip install #{pkg.shellescape} 2>&1"
    )
  end

  def list_requirements
    if cli.ask_user(
      'Would you like to see all the requirements before starting?',
      'no', %w(yes no)
    ) == 'yes'
      cli.puts ''
      req_path = File.join(MiGA.root_path, 'utils', 'requirements.txt')
      File.open(req_path, 'r') do |fh|
        fh.each_line { |ln| cli.puts ln }
      end
      cli.puts ''
    end
  end

  private

  def check_software_requirements(rc_fh)
    cli.puts 'Looking for requirements:'
    ask_for_optional(:mytaxa, 'MyTaxa')
    rc_fh.puts "export MIGA_MYTAXA='#{cli[:mytaxa] ? 'yes' : 'no'}'"
    ask_for_optional(:rdp, 'RDP classifier')
    rc_fh.puts "export MIGA_RDP='#{cli[:rdp] ? 'yes' : 'no'}'"
    paths = {}
    rc_fh.puts 'MIGA_PATH=""'
    req_path = File.expand_path('utils/requirements.txt', MiGA.root_path)
    File.open(req_path, 'r') do |fh|
      fh.each_line do |ln|
        r = define_software(ln) or next
        cli.print "Testing #{r[0]}#{" (#{r[3]})" if r[3]}... "
        path = find_software(r[1])
        paths[r[1]] = File.expand_path(r[1], path).shellescape
      end
    end
    rc_fh.puts 'export PATH="$MIGA_PATH$PATH"'
    cli.puts ''
    paths
  end

  def define_software(ln)
    r = ln.chomp.split(/\t+/)
    return if %w[Software --------].include?(r[0])
    return if r[0] =~ /\(mytaxa\)$/ && !cli[:mytaxa]
    return if r[0] =~ /\(rdp\)$/ && !cli[:rdp]

    r
  end

  def ask_for_optional(symbol, name)
    if cli[symbol].nil?
      cli[symbol] =
        cli.ask_user(
          "Should I include #{name} modules?",
          'yes', %w(yes no)
        ) == 'yes'
    end
  end

  def find_software(exec)
    path = nil
    loop do
      d_path = File.dirname(run_cmd(cli, "which #{exec.shellescape}"))
      if cli[:ask] || d_path == '.'
        path = cli.ask_user('Where can I find it?', d_path, nil, true)
      else
        path = d_path
        cli.puts path
      end
      if File.executable?(File.expand_path(exec, path))
        if d_path != path
          rc_fh.puts "MIGA_PATH=\"#{path}:$MIGA_PATH\" # #{exec}"
        end
        break
      end
      cli.print "I cannot find #{exec} "
    end
    path
  end

  def check_r_packages(paths)
    cli.puts 'Looking for R packages:'
    %w(ape cluster vegan).each do |pkg|
      cli.print "Testing #{pkg}... "
      if test_r_package(cli, paths, pkg)
        cli.puts 'yes'
      else
        cli.puts 'no, installing'
        cli.print '' + install_r_package(cli, paths, pkg)
        unless test_r_package(cli, paths, pkg)
          raise "Unable to auto-install R package: #{pkg}"
        end
      end
    end
    cli.puts ''
  end

  def check_ruby_gems(paths)
    cli.puts 'Looking for Ruby gems:'
    %w[sqlite3 daemons json].each do |pkg|
      cli.print "Testing #{pkg}... "
      if test_ruby_gem(cli, paths, pkg)
        cli.puts 'yes'
      else
        cli.puts 'no, installing'
        cli.print install_ruby_gem(cli, paths, pkg)
        unless test_ruby_gem(cli, paths, pkg)
          raise "Unable to auto-install Ruby gem: #{pkg}"
        end
      end
    end
    cli.puts ''
  end

  def check_python_libraries(paths)
    cli.puts 'Looking for Python libraries:'
    %w[numpy].each do |pkg|
      cli.print "Testing #{pkg}... "
      if test_python_library(cli, paths, pkg)
        cli.puts 'yes'
      else
        cli.puts 'no, installing'
        cli.print install_python_library(cli, paths, pkg)
        unless test_python_library(cli, paths, pkg)
          raise "Unable to auto-install Python library: #{pkg}"
        end
      end
    end
    cli.puts ''
  end
end
