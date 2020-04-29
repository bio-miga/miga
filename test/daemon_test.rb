require 'test_helper'
require 'miga/daemon'

class DaemonTest < Test::Unit::TestCase

  def setup
    $jruby_tests = !ENV['JRUBY_TESTS'].nil?
    $tmp = Dir.mktmpdir
    ENV['MIGA_HOME'] = $tmp
    FileUtils.touch(File.expand_path('.miga_rc', ENV['MIGA_HOME']))
    daemon_json = File.expand_path('.miga_daemon.json', ENV['MIGA_HOME'])
    File.open(daemon_json, 'w') do |fh|
      fh.puts '{"maxjobs":1,"ppn":1,"latency":2,"varsep":" ",
        "var":"{{key}}={{value}}","cmd":"echo {{task_name}} >/dev/null",
        "alive":"echo 1 # {{pid}}","type":"bash","format_version":1}'
    end
    $p1 = MiGA::Project.new(File.expand_path('project1', $tmp))
    $d1 = MiGA::Daemon.new($p1)
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV['MIGA_HOME'] = nil
  end

  def helper_datasets_with_results(n = 1)
    p1 = $p1
    Array.new(n) do |i|
      d = "d#{i}"
      FileUtils.touch(File.expand_path(
        "data/02.trimmed_reads/#{d}.1.clipped.fastq", p1.path
      ))
      FileUtils.touch(File.expand_path(
        "data/02.trimmed_reads/#{d}.done", p1.path
      ))
      p1.add_dataset(MiGA::Dataset.new(p1, d, true).name).tap do |ds|
        ds.first_preprocessing(true)
      end
    end
  end

  def test_check_project
    d1 = $d1
    helper_datasets_with_results.first.inactivate!
    out = capture_stderr { d1.check_project }
    assert_match(/Queueing miga-project:p/, out.string)
    assert_equal(1, d1.jobs_to_run.size)
    assert_equal(:p, d1.jobs_to_run.first[:job])
    assert_equal('project1:p:miga-project', d1.get_job(:p)[:task_name])
  end

  def test_check_datasets
    p = $p1
    d = $d1
    d.runopts(:maxjobs, 0, true)
    assert_empty(d.jobs_to_run)
    ds = p.add_dataset('ds1')
    d.check_datasets
    assert_empty(d.jobs_to_run)
    FileUtils.cp(
      File.expand_path('daemon/daemon.json', p.path),
      File.expand_path('data/01.raw_reads/ds1.1.fastq', p.path)
    )
    FileUtils.cp(
      File.expand_path('daemon/daemon.json', p.path),
      File.expand_path('data/01.raw_reads/ds1.done', p.path)
    )
    ds.first_preprocessing(true)
    out = capture_stderr do
      d.check_datasets
    end
    assert_match(/Queueing #{ds.name}:d/, out.string)
    assert_equal(1, d.jobs_to_run.size)
    assert_equal('echo project1:d:ds1 >/dev/null', d.jobs_to_run.first[:cmd])
    assert_equal(d.jobs_to_run.first, d.get_job(:d, ds))
  end

  def test_in_loop
    p = $p1
    d = $d1
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
    p = $p1
    d = $d1
    d.runopts(:latency, 0, true)
    assert_equal(0, d.latency)
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
    child = $child = d.daemon(:start, ['--shush'])
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
      5 => /Probing running jobs\n/
    }.each { |k, v| assert_match(v, l[k], "unexpected line: #{k}") }
  ensure
    begin
      Process.kill('KILL', $child) if !$child.nil?
    rescue Errno::ESRCH
      false
    end
  end

  def test_last_alive
    p = MiGA::Project.new(File.expand_path('last_alive', $tmp))
    d = MiGA::Daemon.new(p)
    assert_nil(d.last_alive)
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
    d.declare_alive
    assert_lt(d.last_alive, Time.now)
  end

  def test_options
    d1 = $d1
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
    out = capture_stderr { $d1.say 'Olm' }.string
    assert_match(/^\[.*\] Olm/, out)
  end

  def test_terminate
    d = $d1
    assert_not_predicate(d, :active?)
    assert_path_not_exist(d.alive_file)
    assert_path_not_exist(d.terminated_file)

    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
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
    d1 = $d1
    helper_datasets_with_results(3)
    assert_equal(0, d1.jobs_running.size)
    assert_equal(0, d1.jobs_to_run.size)
    capture_stderr { d1.in_loop }
    assert_equal(1, d1.jobs_running.size)
    assert_equal(2, d1.jobs_to_run.size)
  end

  def test_maxjobs_runopts
    d1 = $d1
    helper_datasets_with_results(3)
    d1.runopts(:maxjobs, 2)
    assert_equal(0, d1.jobs_running.size)
    assert_equal(0, d1.jobs_to_run.size)
    capture_stderr { d1.in_loop }
    assert_equal(2, d1.jobs_running.size)
    assert_equal(1, d1.jobs_to_run.size)
  end

  def test_load_status
    d1 = $d1
    p1 = $p1
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
    d1 = $d1
    p1 = $p1
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
    d1 = $d1
    f = File.join($tmp, 'nodes.txt')
    File.open(f, 'w') { |h| h.puts 'localhost' }
    assert_equal(true, d1.next_host)
    out = capture_stderr { d1.runopts(:nodelist, f) }.string
    assert_match(/Reading node list:/, out)
    assert_equal(true, d1.next_host)
    d1.runopts(:type, 'ssh')
    assert_equal(0, d1.next_host)
    f = File.join($p1.path, 'daemon', 'status.json')
    File.open(f, 'w') do |h|
      h.puts '{"jobs_running":[{"job":"p","hostk":0}], "jobs_to_run":[]}'
    end
    capture_stderr { d1.load_status }
    assert_nil(d1.next_host)
  end

  def test_shutdown_when_done
    $d1.runopts(:shutdown_when_done, true)
    out = capture_stderr { assert { !$d1.in_loop } }.string
    assert_match(/Nothing else to do/, out)
  end

  def test_update_format_0
    f = File.join($tmp, 'daemon.json')
    File.open(f, 'w') do |fh|
      fh.puts '{"maxjobs":1,"ppn":1,"latency":2,"varsep":" ",
        "var":"%1$s=%1$s","cmd":"echo %1$s","alive":"echo %1$d","type":"bash"}'
    end
    d2 = MiGA::Daemon.new($p1, f)
    assert_equal('echo {{script}}', d2.runopts(:cmd))
    assert_equal('echo {{pid}}', d2.runopts(:alive))
  end

  def test_launch_job_bash
    t = File.join($tmp, 'launch_job_bash')
    $d1.runopts(:type, 'bash')
    $d1.runopts(:cmd, "echo {{task_name}} > '#{t}'")
    helper_daemon_launch_job
    assert_equal("project1:p:miga-project\n", File.read(t))
  end

  def test_launch_job_ssh
    d1 = $d1
    t = File.join($tmp, 'launch_job_ssh')
    d1.runopts(:type, 'ssh')
    d1.runopts(:cmd, "echo {{task_name}} > '#{t}'")
    f = File.join($tmp, 'nodes.txt')
    File.open(f, 'w') { |h| h.puts 'localhost' }
    assert_raise('Unset environment variable: $MIGA_TEST_NODELIST') do
      d1.runopts(:nodelist, '$MIGA_TEST_NODELIST')
    end
    ENV['MIGA_TEST_NODELIST'] = f
    capture_stderr { d1.runopts(:nodelist, '$MIGA_TEST_NODELIST') }
    helper_daemon_launch_job
    assert_equal("project1:p:miga-project\n", File.read(t))
  end

  def test_launch_job_qsub
    $d1.runopts(:type, 'qsub')
    $d1.runopts(:cmd, 'echo {{task_name}}')
    helper_daemon_launch_job
    assert_equal('project1:p:miga-project', $d1.jobs_running.first[:pid])
  end

  def test_launch_job_failure
    d1 = $d1
    d1.runopts(:type, 'qsub')
    d1.runopts(:cmd, 'echo ""')
    helper_datasets_with_results.first.inactivate!
    capture_stderr { d1.check_project }
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
    out = capture_stderr { d1.launch_job(d1.jobs_to_run.shift) }.string
    assert_match(/Unsuccessful project1:p:miga-project, rescheduling/, out)
    assert_equal(0, d1.jobs_running.size)
    assert_equal(1, d1.jobs_to_run.size)
  end

  def test_verbosity
    d1 = $d1
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

  def helper_daemon_launch_job
    omit_if($jruby_tests, 'JRuby doesn\'t implement fork.')
    d1 = $d1
    helper_datasets_with_results.first.inactivate!
    assert_equal(0, d1.jobs_to_run.size, 'The queue should be empty')
    capture_stderr { d1.check_project }
    assert_equal(1, d1.jobs_to_run.size, 'The queue should have one job')
    capture_stderr { d1.flush! }
    sleep(1)
    assert_equal(0, d1.jobs_to_run.size, 'There should be nothing running')
    assert_equal(1, d1.jobs_running.size, 'There should be one job running')
  end
end
