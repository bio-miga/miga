require 'test_helper'
require 'miga/project'

class HookTest < Test::Unit::TestCase
  
  def setup
    $tmp = Dir.mktmpdir
    ENV['MIGA_HOME'] = $tmp
    FileUtils.touch("#{ENV['MIGA_HOME']}/.miga_rc")
    FileUtils.touch("#{ENV['MIGA_HOME']}/.miga_daemon.json")
    $p1 = MiGA::Project.new(File.expand_path('project1', $tmp))
    $d1 = $p1.add_dataset('dataset1')
  end

  def teardown
    FileUtils.rm_rf $tmp
    ENV['MIGA_HOME'] = nil
  end

  def test_add_hook
    assert_nil($d1.hooks[:on_save])
    $d1.add_hook(:on_save, :run_lambda, Proc.new { $counter += 1 })
    assert_equal(1, $d1.hooks[:on_save].size)
    $counter = 1
    $d1.save
    assert_equal(2, $counter)
  end

  def test_missing_action
    $d1.add_hook(:on_save, :this_is_not_an_action)
    assert_raise do
      $d1.save
    end
  end

  class MyHanger
    include MiGA::Common::Hooks
  end

  def test_empty_hooks
    a = MyHanger.new
    assert_equal({}, a.hooks)
  end

  def test_dataset_result_hooks
    $res = :test
    $counter = 1
    $d1.add_hook(:on_result_ready,
      :run_lambda, Proc.new { |r| $res = r })
    $d1.add_hook(:on_result_ready_trimmed_reads,
      :run_lambda, Proc.new { $counter += 1 })
    FileUtils.touch(File.expand_path(
      "data/02.trimmed_reads/#{$d1.name}.1.clipped.fastq", $p1.path))
    FileUtils.touch(File.expand_path(
      "data/02.trimmed_reads/#{$d1.name}.done", $p1.path))
    assert_equal(:test, $res)
    $d1.add_result(:trimmed_reads)
    assert_equal(:trimmed_reads, $res)
    assert_equal(2, $counter)
  end

  def test_dataset_clear_run_counts
    $d1.metadata[:_try_something] = 1
    $d1.metadata[:_not_a_counter] = 1
    $d1.save
    assert_equal(1, $d1.metadata[:_try_something])
    $d1.add_hook(:on_remove, :clear_run_counts)
    $d1.remove!
    assert_nil($d1.metadata[:_try_something])
    assert_equal(1, $d1.metadata[:_not_a_counter])
  end

  def test_dataset_run_cmd
    f = File.expand_path('hook_ds_cmd', $tmp)
    $d1.metadata[:on_remove] = [[:run_cmd, "echo {{dataset}} > '#{f}'"]]
    assert(! File.exist?(f))
    $d1.remove!
    assert(File.exist? f)
    assert_equal($d1.name, File.read(f).chomp)
  end

  def test_project_run_cmd
    f = File.expand_path('hook_pr_cmd', $tmp)
    $p1.add_hook(:on_save, :run_cmd, "echo {{project}} > '#{f}'")
    assert(! File.exist?(f))
    $p1.save
    assert(File.exist? f)
    assert_equal($p1.path, File.read(f).chomp)
  end

  def test_project_result_hooks
    $res = :test
    $counter = 1
    $p1.add_hook(:on_result_ready,
      :run_lambda, Proc.new { |r| $res = r })
    $p1.add_hook(:on_result_ready_project_stats,
      :run_lambda, Proc.new { $counter += 1 })
    %w[taxonomy.json metadata.db done].each do |ext|
      FileUtils.touch(File.expand_path(
        "data/90.stats/miga-project.#{ext}", $p1.path))
    end
    assert_equal(:project_stats, $p1.next_task(nil, false))
    assert_equal(:test, $res)
    assert_equal(1, $counter)
    assert_equal(:haai_distances, $p1.next_task)
    assert_equal(:project_stats, $res)
    assert_equal(2, $counter)
  end

end
