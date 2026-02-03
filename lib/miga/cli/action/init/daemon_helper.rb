# frozen_string_literal: true

##
# Helper module with daemon configuration functions for MiGA::Cli::Action::Init
module MiGA::Cli::Action::Init::DaemonHelper
  def configure_daemon
    cli.puts 'Default daemon configuration:'
    daemon_f = File.expand_path('.miga_daemon.json', ENV['MIGA_HOME'])
    unless File.exist?(daemon_f) and cli.ask_user(
      'A template daemon already exists, do you want to preserve it?',
      'yes', %w(yes no)
    ) == 'yes'
      v = { created: Time.now.to_s, updated: Time.now.to_s }
      v[:type] = cli.ask_user(
        'Please select the type of daemon you want to setup',
        cli[:dtype], %w(bash ssh qsub msub slurm)
      )
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
      v[:format_version] = 1
      File.open(daemon_f, 'w') { |fh| fh.puts JSON.pretty_generate(v) }
    end
    cli.puts ''
  end

  def configure_bash_daemon(v)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '2').to_i
    v[:maxjobs] = cli.ask_user('How many jobs can I launch at once?', '6').to_i
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    v[:nodelist] = nil # <- To enable non-default with default SSH
    cli.puts 'Setting up internal daemon defaults.'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd] = cli.ask_user(
      "How should I launch tasks?\n" \
        "  {{variables}}: script, vars, cpus, log, task_name, miga\n ",
      "{{vars}} {{miga}} run -r '{{script}}' -l '{{log}}' -e"
    )
    v[:var] = cli.ask_user(
      "How should I pass variables?\n" \
        "  {{variables}}: key, value\n ",
      "{{key}}={{value}}"
    )
    v[:varsep]  = cli.ask_user('What should I use to separate variables?', ' ')
    v[:alive]   = cli.ask_user(
      "How can I know that a process is still alive?\n" \
        "  Output should be 1 for running and 0 for non-running\n" \
        "  {{variables}}: pid\n ",
      "ps -p '{{pid}}' | tail -n +2 | wc -l"
    )
    v[:kill] = cli.ask_user(
      "How should I terminate tasks?\n" \
        "  {{variables}}: pid\n ",
      "kill -9 '{{pid}}'"
    )
    v
  end

  def configure_ssh_daemon(v)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '3').to_i
    v[:nodelist] = cli.ask_user(
      'What environmental variable points to node list?', '$MIGA_NODELIST'
    )
    v[:ppn] = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    cli.puts 'Setting up internal daemon defaults.'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd] = cli.ask_user(
      "How should I launch tasks?\n" \
        "  {{variables}}: script, vars, cpus, log, task_name, miga, host\n ",
      "{{vars}} {{miga}} run -r '{{script}}' -l '{{log}}' -R {{host}} -e"
    )
    v[:var] = cli.ask_user(
      "How should I pass variables?\n" \
        "  {{variables}}: key, value\n ",
      "{{key}}={{value}}"
    )
    v[:varsep]  = cli.ask_user('What should I use to separate variables?', ' ')
    v[:alive]   = cli.ask_user(
      "How can I know that a process is still alive?\n" \
        "  Output should be 1 for running and 0 for non-running\n" \
        "  {{variables}}: pid\n ",
      "ps -p '{{pid}}' | tail -n +2 | wc -l"
    )
    v[:kill] = cli.ask_user(
      "How should I terminate tasks?\n" \
        "  {{variables}}: pid\n ",
      "kill -9 '{{pid}}'"
    )
    v
  end

  def configure_slurm_daemon(v)
    queue       = cli.ask_user('What queue should I use?', nil, nil, true)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '150').to_i
    v[:maxjobs] = cli.ask_user('How many jobs can I launch at once?', '300').to_i
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    v[:nodelist] = nil # <- To enable non-default with default SSH
    cli.puts 'Setting up internal daemon defaults'
    cli.puts 'If you don\'t understand this just leave default values:'
    v[:cmd] = cli.ask_user(
      "How should I launch tasks?\n" \
        "  {{variables}}: script, vars, cpus, log, task_name, miga\n ",
      "{{vars}} sbatch --parsable --partition='#{queue}' --export=ALL " \
        "--nodes=1 --ntasks-per-node={{cpus}} --output='{{log}}' " \
        "--job-name='{{task_name}}' --mem=9G --time=12:00:00 {{script}}"
    )
    v[:var] = cli.ask_user(
      "How should I pass variables?\n" \
        "  {{variables}}: key, value\n ",
      "{{key}}={{value}}"
    )
    v[:varsep] = cli.ask_user(
      'What should I use to separate variables?', ' '
    )
    v[:alive] = cli.ask_user(
      "How can I know that a process is still alive?\n" \
        "  Output should be 1 for running and 0 for non-running\n" \
        "  {{variables}}: pid\n ",
      "squeue -h -o %t -j '{{pid}}' | grep '^PD\\|R\\|CF\\|CG$' " \
        "| tail -n 1 | wc -l"
    )
    v[:kill] = cli.ask_user(
      "How should I terminate tasks?\n" \
        "  {{variables}}: pid\n ",
      "scancel '{{pid}}'"
    )
    v
  end

  def configure_qsub_msub_daemon(v)
    flavor      = v[:type] == 'msub' ? 'msub' :
                  cli.ask_user('Select qsub flavor', 'torque', %w[torque sge])
    queue       = cli.ask_user('What queue should I use?', nil, nil, true)
    v[:latency] = cli.ask_user('How long should I sleep? (in secs)', '150').to_i
    v[:maxjobs] = cli.ask_user('How many jobs can I launch at once?', '300').to_i
    v[:ppn]     = cli.ask_user('How many CPUs can I use per job?', '2').to_i
    v[:nodelist] = nil # <- To enable non-default with default SSH
    cli.puts 'Setting up internal daemon defaults.'
    cli.puts 'If you don\'t understand this just leave default values:'
    if flavor == 'sge'
      v[:cmd] = cli.ask_user(
        "How should I launch tasks?\n" \
          "  {{variables}}: script, vars, cpus, log, task_name, task_name_simple\n ",
        "#{v[:type]} -q '#{queue}' -v '{{vars}}' -pe openmp {{cpus}} " \
          "-j y -o '{{log}}' -N '{{task_name_simple}}' -l h_vmem=9g " \
          "-l h_rt=12:00:00 '{{script}}' | grep . " \
          "| perl -pe 's/^Your job (\\S+) .*/$1/'"
      )
    else
      v[:cmd] = cli.ask_user(
        "How should I launch tasks?\n" \
          "  {{variables}}: script, vars, cpus, log, task_name, task_name_simple\n ",
        "#{v[:type]} -q '#{queue}' -v '{{vars}}' -l nodes=1:ppn={{cpus}} " \
          "-j oe -o '{{log}}' -N '{{task_name}}' -l mem=9g " \
          "-l walltime=12:00:00 '{{script}}' | grep ."
      )
    end
    v[:var] = cli.ask_user(
      "How should I pass variables?\n" \
        "  {{variables}}: key, value\n ",
      "{{key}}={{value}}"
    )
    v[:varsep] = cli.ask_user(
      'What should I use to separate variables?', ','
    )
    if v[:type] == 'qsub'
      if flavor == 'sge'
        v[:alive] = cli.ask_user(
          "How can I know that a process is still alive?\n" \
            "  Output should be 1 for running and 0 for non-running\n" \
            "  {{variables}}: pid\n ",
          "qstat -j '{{pid}}' -s pr 2>/dev/null | head -n 1 | wc -l " \
            "| awk '{print $1}'"
        )
      else
        v[:alive] = cli.ask_user(
          "How can I know that a process is still alive?\n" \
            "  Output should be 1 for running and 0 for non-running\n" \
            "  {{variables}}: pid\n ",
          "qstat -f '{{pid}}' | grep ' job_state =' | perl -pe 's/.*= //' " \
            "| grep '[^C]' | tail -n 1 | wc -l | awk '{print $1}'"
        )
      end
      v[:kill] = cli.ask_user(
        "How should I terminate tasks?\n" \
          "  {{variables}}: pid\n ",
        "qdel '{{pid}}'"
      )
    else # msub
      v[:alive] = cli.ask_user(
        "How can I know that a process is still alive?\n" \
          "  Output should be 1 for running and 0 for non-running\n" \
          "  {{variables}}: pid\n ",
        "checkjob '{{pid}}'|grep '^State:' | perl -pe 's/.*: //' " \
          "| grep 'Deferred\\|Hold\\|Idle\\|Starting\\|Running\\|Blocked'" \
          "| tail -n 1 | wc -l | awk '{print $1}'"
      )
      v[:kill] = cli.ask_user(
        "How should I terminate tasks?\n" \
          "  {{variables}}: pid\n ",
        "canceljob '{{pid}}'"
      )
    end
    v
  end
end
