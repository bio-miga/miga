require 'test_helper'
require 'miga/project'

class HookTest < Test::Unit::TestCase
  include TestHelper

  def setup
    initialize_miga_home
  end

  def test_add_hook
    assert_nil(dataset.hooks[:on_save])
    dataset.add_hook(:on_save, :run_lambda, Proc.new { $counter += 1 })
    assert_equal(1, dataset.hooks[:on_save].size)
    $counter = 1
    dataset.save
    assert_equal(2, $counter)
  end

  def test_missing_action
    dataset.add_hook(:on_save, :this_is_not_an_action)
    assert_raise { dataset.save }
  end

  ##
  # Dummy class with hooks
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
    dataset.add_hook(:on_result_ready, :run_lambda, Proc.new { |r| $res = r })
    dataset.add_hook(
      :on_result_ready_trimmed_reads, :run_lambda, Proc.new { $counter += 1 }
    )
    FileUtils.touch(
      File.join(
        project.path, 'data', '02.trimmed_reads',
        "#{dataset.name}.1.clipped.fastq"
      )
    )
    FileUtils.touch(
      File.join(
        project.path, 'data', '02.trimmed_reads', "#{dataset.name}.done"
      )
    )
    assert_equal(:test, $res)
    dataset.add_result(:trimmed_reads)
    assert_equal(:trimmed_reads, $res)
    assert_equal(2, $counter)
  end

  def test_dataset_clear_run_counts
    dataset.metadata[:_try_something] = 1
    dataset.metadata[:_step] = 'Boop'
    dataset.metadata[:_not_a_counter] = 1
    dataset.save
    assert_equal(1, dataset.metadata[:_try_something])
    assert_equal('Boop', dataset.metadata[:_step])
    dataset.add_hook(:on_remove, :clear_run_counts)
    dataset.remove!
    assert_nil(dataset.metadata[:_try_something])
    assert_nil(dataset.metadata[:_step])
    assert_equal(1, dataset.metadata[:_not_a_counter])
  end

  def test_dataset_run_cmd
    f = tmpfile('hook_ds_cmd')
    dataset.metadata[:on_remove] = [[:run_cmd, "echo {{dataset}} > '#{f}'"]]
    assert_path_not_exist(f)
    dataset.remove!
    assert_path_exist(f)
    assert_equal(dataset.name, File.read(f).chomp)
  end

  def test_project_run_cmd
    f = tmpfile('hook_pr_cmd')
    project.add_hook(:on_save, :run_cmd, "echo {{project}} > '#{f}'")
    assert_path_not_exist(f)
    project.save
    assert_path_exist(f)
    assert_equal(project.path, File.read(f).chomp)
  end

  def test_project_result_hooks
    $res = :test
    $counter = 1
    project.add_hook(
      :on_result_ready,
      :run_lambda,
      Proc.new { |r| $res = r }
    )
    project.add_hook(
      :on_result_ready_project_stats,
      :run_lambda,
      Proc.new { $counter += 1 }
    )
    %w[taxonomy.json metadata.db done].each do |ext|
      FileUtils.touch(
        File.join(project.path, 'data', '90.stats', "miga-project.#{ext}")
      )
    end
    assert_equal(:project_stats, project.next_task(nil, false))
    assert_equal(:test, $res)
    assert_equal(1, $counter)
    assert_equal(:haai_distances, project.next_task)
    assert_equal(:project_stats, $res)
    assert_equal(2, $counter)
  end
end
