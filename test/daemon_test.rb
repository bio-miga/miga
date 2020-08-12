require 'test_helper'
require 'daemon_helper'
require 'miga/daemon'

class DaemonTest < Test::Unit::TestCase
  include TestHelper
  include DaemonHelper

  def setup
    initialize_miga_home(
      <<~DAEMON
        { "maxjobs": 1, "ppn": 1, "latency": 2, "varsep": " ", "show_log": true,
          "var": "{{key}}={{value}}", "cmd": "echo {{task_name}} >/dev/null",
          "alive": "echo 1 # {{pid}}", "type": "bash", "format_version": 1 }
      DAEMON
    )
  end

  def test_check_project
    d1 = daemon(1)
    helper_datasets_with_results(1, 1).first.inactivate!
    out = capture_stderr { d1.check_project }.string
    assert_match(/Queueing miga-project:p/, out)
    assert_equal(1, d1.jobs_to_run.size)
    assert_equal(:p, d1.jobs_to_run.first[:job])
    assert_equal('project1:p:miga-project', d1.get_job(:p)[:task_name])
  end

  def test_check_datasets
    p = project
    d = daemon
    d.runopts(:maxjobs, 0, true)
    assert_empty(d.jobs_to_run)
    ds = p.add_dataset('ds1')
    d.check_datasets
    assert_empty(d.jobs_to_run)
    FileUtils.cp(
      File.join(p.path, 'daemon/daemon.json'),
      File.join(p.path, 'data/01.raw_reads/ds1.1.fastq')
    )
    FileUtils.cp(
      File.join(p.path, 'daemon/daemon.json'),
      File.join(p.path, 'data/01.raw_reads/ds1.done')
    )
    ds.first_preprocessing(true)
    out = capture_stderr do
      d.check_datasets
    end
    assert_match(/Queueing #{ds.name}:d/, out.string)
    assert_equal(1, d.jobs_to_run.size)
    assert_equal('echo project0:d:ds1 >/dev/null', d.jobs_to_run.first[:cmd])
    assert_equal(d.jobs_to_run.first, d.get_job(:d, ds))
  end

  def test_in_loop
    p = project
    d = daemon
    d.runopts(:latency, 0, true)
    assert_nil(d.loop_i)
    assert_nil(d.last_alive)
    out = capture_stderr { d.in_loop }.string
    assert_equal(Time, d.last_alive.class)
    assert_match(/-{20}\n.*MiGA:#{p.name} launched/, out)
    11.times { d.in_loop }
    assert_equal(11, d.loop_i)
    out = capture_stderr { d.in_loop }.string
    assert_match(/Probing running jobs/, out)
    assert_equal(12, d.loop_i)
  end

  def test_start
    p = project
    d = daemon
    d.runopts(:latency, 0, true)
    assert_equal(0, d.latency)

    declare_forks
    child = d.daemon(:start, ['--shush'])
    assert_not_nil(child)
    assert_gt(child, 1)
    assert_equal(0, `ps -p "#{child}" -o ppid=`.strip.to_i,
                 'The daemon process should be detached')
    sleep(3)
    assert_path_exist(d.pid_file)
    out = capture_stderr { d.stop }.string
    assert_raise(Errno::ESRCH) { Process.kill(0, child) }
    assert_match(/Sending termination message/, out)
    assert_path_not_exist(d.pid_file)
    assert_path_exist(d.output_file)
    assert_equal(1, d.verbosity)
    l = File.readlines(d.output_file)
    {
      0 => /-{20}\n/,
      1 => /MiGA:#{p.name} launched/,
      2 => /-{20}\n/,
      6 => /Probing running jobs\n/
    }.each { |k, v| assert_match(v, l[k], "unexpected line: #{k}") }
  ensure
    begin
      Process.kill('KILL', child) unless child.nil?
    rescue Errno::ESRCH
      false
    end
  end

  def test_last_alive
    p = MiGA::Project.new(tmpfile('last_alive'))
    d = MiGA::Daemon.new(p)
    assert_nil(d.last_alive)

    declare_forks
    d.declare_alive
    assert_lt(d.last_alive, Time.now)
  end

  def test_options
    d1 = daemon
    assert_respond_to(d1, :default_options)
    assert_equal(:normal, d1.default_options[:dir_mode])
    assert_equal(2, d1.runopts(:latency))
    assert_equal(1, d1.maxjobs)
    assert_equal(2, d1.latency)
    assert_equal(1, d1.ppn)
    d1.runopts(:alo, :ha)
    assert_equal(:ha, d1.runopts(:alo))
    d1.runopts(:maxjobs, '1')
    assert_equal(1, d1.maxjobs)
    assert_raise { d1.runopts(:latency, '!') }
    assert_equal('bash', d1.runopts(:type))
  end

  def test_say
    out = capture_stderr { daemon.say 'Olm' }.string
    assert_match(/^\[.*\] Olm/, out)
  end

  def test_terminate
    d = daemon
    assert_not_predicate(d, :active?)
    assert_path_not_exist(d.alive_file)
    assert_path_not_exist(d.terminated_file)

    declare_forks
    d.declare_alive
    assert_predicate(d, :active?)
    assert_not_nil(d.last_alive)
    assert_path_exist(d.alive_file)
    assert_path_not_exist(d.terminated_file)

    d.terminate
    assert_path_not_exist(d.alive_file)
    assert_path_exist(d.terminated_file)
    assert_not_predicate(d, :active?)
    assert_not_nil(d.last_alive)
  end

  def test_maxjobs_json
    d1 = daemon
    helper_datasets_with_results(3)
    assert_equal(0, d1.jobs_running.size)
    assert_equal(0, d1.jobs_to_run.size)
    capture_stderr { d1.in_loop }
    assert_equal(1, d1.jobs_running.size)
    assert_equal(2, d1.jobs_to_run.size)
  end

  def test_maxjobs_runopts
    d1 = daemon
    helper_datasets_with_results(3)
    d1.runopts(:maxjobs, 2)
    assert_equal(0, d1.jobs_running.size)
    assert_equal(0, d1.jobs_to_run.size)
    capture_stderr { d1.in_loop }
    assert_equal(2, d1.jobs_running.size)
    assert_equal(1, d1.jobs_to_run.size)
  end

  def test_load_status
    d1 = daemon
    p1 = project
    assert_equal(0, d1.jobs_running.size)
    assert_nil(d1.load_status)
    assert_equal(0, d1.jobs_running.size)
    p1.add_dataset(MiGA::Dataset.new(p1, 'd1').name)
    f = File.join(p1.path, 'daemon', 'status.json')
    File.open(f, 'w') do |h|
      h.puts '{"jobs_running":[{"ds":1,"ds_name":"d1"},{}],"jobs_to_run":[]}'
    end
    out = capture_stderr { d1.load_status }.string
    assert_equal(2, d1.jobs_running.size)
    assert_match(/Loading previous status/, out)
    assert_equal(MiGA::Dataset, d1.jobs_running[0][:ds].class)
    assert_nil(d1.jobs_running[1][:ds])
  end

  def test_flush
    d1 = daemon
    p1 = project
    helper_datasets_with_results
    p1.add_dataset(MiGA::Dataset.new(p1, 'd1').name)
    MiGA::Project.RESULT_DIRS.keys.each { |i| p1.metadata["run_#{i}"] = false }
    f = File.join(p1.path, 'daemon', 'status.json')
    File.open(f, 'w') do |h|
      h.puts '{"jobs_running":' \
        '[{"job":"p"},{"job":"d","ds":1,"ds_name":"d1"},' \
        '{"job":"trimmed_reads","ds":1,"ds_name":"d0"}]' \
        ',"jobs_to_run":[]}'
    end
    capture_stderr { d1.load_status }
    assert_equal(3, d1.jobs_running.size)
    out = capture_stderr { d1.flush! }.string
    assert_match(/Completed pid:/, out)
    assert_equal([], d1.jobs_running)
  end

  def test_next_host
    d1 = daemon
    f = tmpfile('nodes.txt')
    File.open(f, 'w') { |h| h.puts 'localhost' }
    assert_equal(true, d1.next_host)
    out = capture_stderr { d1.runopts(:nodelist, f) }.string
    assert_match(/Reading node list:/, out)
    assert_equal(true, d1.next_host)
    d1.runopts(:type, 'ssh')
    assert_equal(0, d1.next_host)
    f = File.join(project.path, 'daemon', 'status.json')
    File.open(f, 'w') do |h|
      h.puts '{"jobs_running":[{"job":"p","hostk":0}], "jobs_to_run":[]}'
    end
    capture_stderr { d1.load_status }
    assert_nil(d1.next_host)
  end

  def test_shutdown_when_done
    daemon.runopts(:shutdown_when_done, true)
    out = capture_stderr { assert { !daemon.in_loop } }.string
    assert_match(/Nothing else to do/, out)
  end

  def test_update_format_0
    f = tmpfile('daemon.json')
    File.open(f, 'w') do |fh|
      fh.puts(
        <<~DAEMON
          { "maxjobs": 1, "ppn": 1, "latency": 2, "varsep": " ",
            "var": "%1$s=%1$s", "cmd": "echo %1$s", "alive": "echo %1$d",
            "type": "bash" }
        DAEMON
      )
    end
    d2 = MiGA::Daemon.new(project, f)
    assert_equal('echo {{script}}', d2.runopts(:cmd))
    assert_equal('echo {{pid}}', d2.runopts(:alive))
  end

  def test_launch_job_bash
    t = tmpfile('launch_job_bash')
    daemon.runopts(:type, 'bash')
    daemon.runopts(:cmd, "echo {{task_name}} > '#{t}'")
    helper_daemon_launch_job
    assert_equal("project0:p:miga-project\n", File.read(t))
  end

  def test_launch_job_ssh
    d1 = daemon(1)
    t = tmpfile('launch_job_ssh')
    d1.runopts(:type, 'ssh')
    d1.runopts(:cmd, "echo {{task_name}} > '#{t}'")
    f = tmpfile('nodes.txt')
    File.open(f, 'w') { |h| h.puts 'localhost' }
    assert_raise('Unset environment variable: $MIGA_TEST_NODELIST') do
      d1.runopts(:nodelist, '$MIGA_TEST_NODELIST')
    end
    ENV['MIGA_TEST_NODELIST'] = f
    capture_stderr { d1.runopts(:nodelist, '$MIGA_TEST_NODELIST') }
    helper_daemon_launch_job(1)
    assert_equal("project1:p:miga-project\n", File.read(t))
  end

  def test_launch_job_qsub
    daemon.runopts(:type, 'qsub')
    daemon.runopts(:cmd, 'echo {{task_name}}')
    helper_daemon_launch_job
    assert_equal('project0:p:miga-project', daemon.jobs_running.first[:pid])
  end

  def test_launch_job_failure
    d1 = daemon(1)
    d1.runopts(:type, 'qsub')
    d1.runopts(:cmd, 'echo ""')
    helper_datasets_with_results(1, 1).first.inactivate!
    capture_stderr { d1.check_project }

    declare_forks
    out = capture_stderr { d1.launch_job(d1.jobs_to_run.shift) }.string
    assert_match(/Unsuccessful project1:p:miga-project, rescheduling/, out)
    assert_equal(0, d1.jobs_running.size)
    assert_equal(1, d1.jobs_to_run.size)
  end

  def test_verbosity
    d1 = daemon
    d1.runopts(:verbosity, 0)
    out = capture_stderr { d1.in_loop }.string
    assert_empty(out)

    d1.runopts(:verbosity, 1)
    helper_datasets_with_results.first.inactivate!
    out = capture_stderr { d1.check_project }
    assert_match(/Queueing miga-project:p/, out.string)

    d1.runopts(:verbosity, 2)
    out = capture_stderr { d1.in_loop }.string
    assert_match(/Reloading project/, out)

    d1.runopts(:verbosity, 3)
    out = capture_stderr { d1.in_loop }.string
    assert_match(/Daemon loop start/, out)
  end
end
