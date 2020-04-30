##
# Helper functions to test daemons.
# The class MUST also include +TestHelper+
module DaemonHelper
  def daemon(i = 0)
    @daemon ||= {}
    @daemon[project(i).name] ||= MiGA::Daemon.new(project(i))
  end

  def helper_datasets_with_results(n = 1, project_i = 0)
    p1 = project(project_i)
    Array.new(n) do |i|
      d = "d#{i}"
      FileUtils.touch(
        File.join(p1.path, 'data', '02.trimmed_reads', "#{d}.1.clipped.fastq")
      )
      FileUtils.touch(
        File.join(p1.path, 'data', '02.trimmed_reads', "#{d}.done")
      )
      p1.add_dataset(MiGA::Dataset.new(p1, d, true).name).tap do |ds|
        ds.first_preprocessing(true)
      end
    end
  end

  def helper_daemon_launch_job(project_i = 0)
    declare_forks
    d1 = daemon(project_i)
    helper_datasets_with_results(1, project_i).first.inactivate!
    assert_equal(0, d1.jobs_to_run.size, 'The queue should be empty')
    capture_stderr { d1.check_project }
    assert_equal(1, d1.jobs_to_run.size, 'The queue should have one job')
    capture_stderr { d1.flush! }
    sleep(1)
    assert_equal(0, d1.jobs_to_run.size, 'There should be nothing running')
    assert_equal(1, d1.jobs_running.size, 'There should be one job running')
  end
end
