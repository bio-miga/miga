# @package MiGA
# @license Artistic-2.0

require 'miga/cli/action'
require 'shellwords'

class MiGA::Cli::Action::Init < MiGA::Cli::Action

  def parse_cli
    cli.interactive = true
    cli.defaults = {mytaxa: nil,
      config: File.expand_path('.miga_modules', ENV['HOME']),
      ask: false, auto: false, dtype: :bash}
    cli.parse do |opt|
      opt.on(
        '-c', '--config PATH',
        'Path to the Bash configuration file',
        "By default: #{cli[:config]}"
        ){ |v| cli[:config] = v }
      opt.on(
        '--[no-]mytaxa',
        'Should I try setting up MyTaxa its dependencies?',
        'By default: interactive (true if --auto)'
        ){ |v| cli[:mytaxa] = v }
      opt.on(
        '--daemon-type STRING',
        'Type of daemon launcher, one of: bash, qsub, msub, slurm',
        "By default: interactive (#{cli[:dtype]} if --auto)"
        ){ |v| cli[:dtype] = v.to_sym }
      opt.on(
        '--ask-all',
        'Ask for the location of all software',
        'By default, only the locations missing in PATH are requested'
        ){ |v| cli[:ask] = v }
    end
  end

  def perform
    cli.puts <<BANNER
===[ Welcome to MiGA, the Microbial Genome Atlas ]===

I'm the initialization script, and I'll sniff around your computer to
make sure you have all the requirements for MiGA data processing.

BANNER
    list_requirements
    rc_fh = open_rc_file
    check_configuration_script rc_fh
    paths = check_software_requirements rc_fh
    check_additional_files paths
    check_r_packages paths
    check_ruby_gems paths
    configure_daemon
    close_rc_file rc_fh
    cli.puts 'Configuration complete. MiGA is ready to work!'
    cli.puts ''
  end

  def empty_action
  end

  def run_cmd(cli, cmd)
    `. "#{cli[:config]}" && #{cmd}`
  end

  def run_r_cmd(cli, paths, cmd)
    run_cmd(cli,
      "echo #{cmd.shellescape} | #{paths['R'].shellescape} --vanilla -q 2>&1")
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
    run_cmd(cli,
      "#{paths['ruby'].shellescape} -r #{pkg.shellescape} -e '' 2>/dev/null")
    $?.success?
  end

  def install_ruby_gem(cli, paths, pkg)
    gem_cmd = "Gem::GemRunner.new.run %w(install --user #{pkg})"
    run_cmd(cli, "#{paths['ruby'].shellescape} \
        -r rubygems -r rubygems/gem_runner \
        -e #{gem_cmd.shellescape} 2>&1")
  end

  def list_requirements
    if cli.ask_user(
          'Would you like to see all the requirements before starting?',
          'no', %w(yes no)) == 'yes'
      cli.puts ''
      req_path = File.expand_path('utils/requirements.txt', MiGA.root_path)
      File.open(req_path, 'r') do |fh|
        fh.each_line { |ln| cli.puts ln }
      end
      cli.puts ''
    end
  end

  private

  def open_rc_file
    rc_path = File.expand_path('.miga_rc', ENV['HOME'])
    if File.exist? rc_path
      if cli.ask_user(
            'I found a previous configuration. Do you want to continue?',
            'yes', %w(yes no)) == 'no'
        cli.puts 'OK, see you soon!'
        exit(0)
      end
    end
    rc_fh = File.open(rc_path, 'w')
    rc_fh.puts <<BASH
#!/bin/bash
# `miga init` made this on #{Time.now}

BASH
    rc_fh
  end

  def check_configuration_script(rc_fh)
    unless File.exist? cli[:config]
      cli[:config] = cli.ask_user(
            'Is there a script I need to load at startup?',
            cli[:config])
    end
    if File.exist? cli[:config]
      cli[:config] = File.expand_path(cli[:config])
      cli.puts "Found bash configuration script: #{cli[:config]}"
      rc_fh.puts "MIGA_STARTUP='#{cli[:config]}'"
      rc_fh.puts '. "$MIGA_STARTUP"'
    else
      cli[:config] = '/dev/null'
    end
    cli.puts ''
  end

  def check_software_requirements(rc_fh)
    cli.puts 'Looking for requirements:'
    if cli[:mytaxa].nil?
      cli[:mytaxa] = cli.ask_user(
            'Should I include MyTaxa modules?',
            'yes', %w(yes no)) == 'yes'
    end
    rc_fh.puts 'export MIGA_MYTAXA="no"' unless cli[:mytaxa]
    paths = {}
    rc_fh.puts 'MIGA_PATH=""'
    req_path = File.expand_path('utils/requirements.txt', MiGA.root_path)
    File.open(req_path, 'r') do |fh|
      fh.each_line do |ln|
        next if $. < 3
        r = ln.chomp.split(/\t+/)
        next if r[0] =~ /\(opt\)$/ && !cli[:mytaxa]
        cli.print "Testing #{r[0]}#{" (#{r[3]})" if r[3]}... "
        path = nil
        loop do
          d_path = File.dirname(run_cmd(cli, "which #{r[1].shellescape}"))
          if cli[:ask] || d_path == '.'
            path = cli.ask_user('Where can I find it?', d_path, nil, true)
          else
            path = d_path
            cli.puts path
          end
          if File.executable?(File.expand_path(r[1], path))
            if d_path != path
              rc_fh.puts "MIGA_PATH=\"#{path}:$MIGA_PATH\" # #{r[1]}"
            end
            break
          end
          cli.print "I cannot find #{r[1]} "
        end
        paths[r[1]] = File.expand_path(r[1], path).shellescape
      end
    end
    rc_fh.puts 'export PATH="$MIGA_PATH$PATH"'
    cli.puts ''
    paths
  end

  def check_additional_files(paths)
    if cli[:mytaxa]
      cli.puts 'Looking for MyTaxa databases:'
      mt = File.dirname paths["MyTaxa"]
      cli.print 'Looking for scores... '
      unless Dir.exist?(File.expand_path('db', mt))
        cli.puts "no.\nExecute 'python2 #{mt}/utils/download_db.py'."
        exit(1)
      end
      cli.puts 'yes.'
      cli.print 'Looking for diamond db... '
      unless File.exist?(File.expand_path('AllGenomes.faa.dmnd', mt))
        cli.puts "no.\nDownload " \
          "'http://enve-omics.ce.gatech.edu/data/public_mytaxa/" \
          "AllGenomes.faa.dmnd' into #{mt}."
        exit(1)
      end
      cli.puts ''
    end
  end

  def check_r_packages(paths)
    cli.puts 'Looking for R packages:'
    %w(enveomics.R ape cluster vegan).each do |pkg|
      cli.print "Testing #{pkg}... "
      if test_r_package(cli, paths, pkg)
        cli.puts 'yes.'
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
    %w(sqlite3 daemons json).each do |pkg|
      cli.print "Testing #{pkg}... "
      if test_ruby_gem(cli, paths, pkg)
        cli.puts 'yes.'
      else
        cli.puts 'no, installing'
        # This hackey mess is meant to ensure the test and installation are done
        # on the configuration Ruby, not on the Ruby currently executing the
        # init action
        cli.print install_ruby_gem(cli, paths, pkg)
        unless test_ruby_gem(cli, paths, pkg)
          raise "Unable to auto-install Ruby gem: #{pkg}"
        end
      end
    end
    cli.puts ''
  end

  def configure_daemon
    cli.puts 'Default daemon configuration:'
    daemon_f = File.expand_path('.miga_daemon.json', ENV['HOME'])
    unless File.exist?(daemon_f) and cli.ask_user(
              'A template daemon already exists, do you want to preserve it?',
              'yes', %w(yes no)) == 'yes'
      v = {created: Time.now.to_s, updated: Time.now.to_s}
      v[:type] = cli.ask_user(
        'Please select the type of daemon you want to setup',
        cli[:dtype], %w(bash qsub msub slurm))
      case v[:type]
      when 'bash'
        v = configure_bash_daemon(v)
      when 'slurm'
        v = configure_slurm_daemon(v)
      else # [qm]sub
        v = configure_qsub_msub_daemon(v)
      end
      File.open(daemon_f, 'w') { |fh| fh.puts JSON.pretty_generate(v) }
    end
    cli.puts ''
  end

  def configure_bash_daemon(v)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '30').to_i
    v[:maxjobs] = cli.ask_user('How many jobs can I launch at once?', '6').to_i
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    cli.puts 'Setting up internal daemon defaults.'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd]     = cli.ask_user(
      "How should I launch tasks?\n  %1$s: script path, " \
        "%2$s: variables, %3$d: CPUs, %4$s: log file, %5$s: task name.\n",
      "%2$s '%1$s' > '%4$s' 2>&1")
    v[:var]     = cli.ask_user(
      "How should I pass variables?\n  %1$s: keys, %2$s: values.\n",
      "%1$s=%2$s")
    v[:varsep]  = cli.ask_user('What should I use to separate variables?', ' ')
    v[:alive]   = cli.ask_user(
      "How can I know that a process is still alive?\n  %1$s: PID, " \
        "output should be 1 for running and 0 for non-running.\n",
      "ps -p '%1$s'|tail -n+2|wc -l")
    v[:kill]    = cli.ask_user(
      "How should I terminate tasks?\n  %s: process ID.", "kill -9 '%s'")
    v
  end

  def configure_slurm_daemon(v)
    queue       = cli.ask_user('What queue should I use?', nil, nil, true)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '150').to_i
    v[:maxjobs] = cli.ask_user('How many jobs can I launch at once?', '300').to_i
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    cli.puts 'Setting up internal daemon defaults'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd]     = cli.ask_user(
      "How should I launch tasks?\n  %1$s: script path, " \
        "%2$s: variables, %3$d: CPUs, %4$d: log file, %5$s: task name.\n",
      "%2$s sbatch --partition='#{queue}' --export=ALL " \
        "--nodes=1 --ntasks-per-node=%3$d --output='%4$s' " \
        "--job-name='%5$s' --mem=9G --time=12:00:00 %1$s " \
        "| perl -pe 's/.* //'")
    v[:var]     = cli.ask_user(
      "How should I pass variables?\n  %1$s: keys, %2$s: values.\n",
      "%1$s=%2$s")
    v[:varsep]  = cli.ask_user(
      'What should I use to separate variables?', ' ')
    v[:alive]   = cli.ask_user(
      "How can I know that a process is still alive?\n  %1$s: job id, " \
        "output should be 1 for running and 0 for non-running.\n",
      "squeue -h -o %%t -j '%1$s' | grep '^PD\\|R\\|CF\\|CG$' " \
        "| tail -n 1 | wc -l")
    v[:kill]    = cli.ask_user(
      "How should I terminate tasks?\n  %s: process ID.", "scancel '%s'")
    v
  end

  def configure_qsub_msub_daemon
    queue       = cli.ask_user('What queue should I use?', nil, nil, true)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '150').to_i
    v[:maxjobs] = cli.ask_user('How many jobs can I launch at once?', '300').to_i
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    cli.puts 'Setting up internal daemon defaults.'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd]     = cli.ask_user(
      "How should I launch tasks?\n  %1$s: script path, " \
        "%2$s: variables, %3$d: CPUs, %4$d: log file, %5$s: task name.\n",
      "#{v[:type]} -q '#{queue}' -v '%2$s' -l nodes=1:ppn=%3$d %1$s " \
        "-j oe -o '%4$s' -N '%5$s' -l mem=9g -l walltime=12:00:00 " \
        "| grep .")
    v[:var]     = cli.ask_user(
      "How should I pass variables?\n  %1$s: keys, %2$s: values.\n",
      "%1$s=%2$s")
    v[:varsep]  = cli.ask_user(
      'What should I use to separate variables?', ',')
    if v[:type] == 'qsub'
      v[:alive] = cli.ask_user(
        "How can I know that a process is still alive?\n  " \
          "%1$s: job id, output should be 1 for running and " \
          "0 for non-running.\n",
        "qstat -f '%1$s'|grep ' job_state ='|perl -pe 's/.*= //'" \
          "|grep '[^C]'|tail -n1|wc -l|awk '{print $1}'")
      v[:kill]  = cli.ask_user(
        "How should I terminate tasks?\n  %s: process ID.", "qdel '%s'")
    else # msub
      v[:alive] = cli.ask_user(
        "How can I know that a process is still alive?\n  " \
          "%1$s: job id, output should be 1 for running and " \
          "0 for non-running.\n",
        "checkjob '%1$s'|grep '^State:'|perl -pe 's/.*: //'" \
          "|grep 'Deferred\\|Hold\\|Idle\\|Starting\\|Running\\|Blocked'" \
          "|tail -n1|wc -l|awk '{print $1}'")
      v[:kill]  = cli.ask_user(
        "How should I terminate tasks?\n  %s: process ID.",
        "canceljob '%s'")
    end
    v
  end

  def close_rc_file(rc_fh)
    rc_fh.puts <<FOOT

MIGA_CONFIG_VERSION='#{MiGA::MiGA.VERSION}'
MIGA_CONFIG_LONGVERSION='#{MiGA::MiGA.LONG_VERSION}'
MIGA_CONFIG_DATE='#{Time.now}'

FOOT
    rc_fh.close
  end
end
