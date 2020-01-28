# @package MiGA
# @license Artistic-2.0

##
# Helper module with daemon configuration functions for MiGA::Cli::Action::Init
module MiGA::Cli::Action::Init::DaemonHelper
  def configure_daemon
    cli.puts 'Default daemon configuration:'
    daemon_f = File.expand_path('.miga_daemon.json', ENV['HOME'])
    unless File.exist?(daemon_f) and cli.ask_user(
              'A template daemon already exists, do you want to preserve it?',
              'yes', %w(yes no)) == 'yes'
      v = {created: Time.now.to_s, updated: Time.now.to_s}
      v[:type] = cli.ask_user(
        'Please select the type of daemon you want to setup',
        cli[:dtype], %w(bash ssh qsub msub slurm))
      case v[:type]
      when 'bash'
        v = configure_bash_daemon(v)
      when 'ssh'
        v = configure_ssh_daemon(v)
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
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '2').to_i
    v[:maxjobs] = cli.ask_user('How many jobs can I launch at once?', '6').to_i
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    cli.puts 'Setting up internal daemon defaults.'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd]     = cli.ask_user(
      "How should I launch tasks?\n  %1$s: script path, " \
        "%2$s: variables, %3$d: CPUs, %4$s: log file, %5$s: task name.\n",
      "%2$s \"`echo \"$MIGA\"`/bin/miga\" run -r '%1$s' -l '%4$s' -e")
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

  def configure_ssh_daemon(v)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '3').to_i
    v[:maxjobs] = cli.ask_user(
      'What environmental variable points to node list?', '$MIGA_NODELIST')
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    cli.puts 'Setting up internal daemon defaults.'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd]     = cli.ask_user(
      "How should I launch tasks?\n  %1$s: script path, " \
        "%2$s: variables, %3$d: CPUs, %4$s: log file, %5$s: task name, " \
        "%6$s: remote host.\n",
      "%2$s \"`echo \"$MIGA\"`/bin/miga\" run -r '%1$s' -l '%4$s' -R '%6$s' -e")
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

end
