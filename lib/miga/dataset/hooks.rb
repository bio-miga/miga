
require 'miga/common/hooks'

##
# Helper module including specific functions to handle dataset hooks.
# Supported events:
# - on_load(): When loaded
# - on_save(): When saved
# - on_remove(): When removed
# - on_inactivate(): When inactivated
# - on_activate(): When activated
# - on_result_ready(result): When any result is ready, with key +result+
# - on_result_ready_{result}(): When +result+ is ready
# - on_preprocessing_ready(): When preprocessing is complete
# Supported hooks:
# - run_lambda(lambda, args...)
# - clear_run_counts()
# - run_cmd(cmd)
# Internal hooks:
# - _pull_preprocessing_ready_hooks()
# - _pull_result_hooks()
module MiGA::Dataset::Hooks 

  include MiGA::Common::Hooks

  def default_hooks
    {
      on_preprocessing_ready: [[:clear_run_counts]],
      on_result_ready: [
        [:_pull_result_hooks],
        [:_pull_preprocessing_ready_hooks]
      ]
    }
  end

  ##
  # Clear metadata from run counts
  def hook_clear_run_counts(_hook_args, _event_args)
    metadata.data.keys
      .select { |k| k.to_s =~ /^_try_/ }
      .each { |k| metadata[k] = nil }
    metadata[:_step] = nil
    save
  end

  ##
  # Run +cmd+ in the command-line with {{variables}}: dataset, project, miga,
  # object (as defined for the event, if any)
  # - +hook_args+: +[cmd]+
  # - +event_args+: +[object (optional)]+
  def hook_run_cmd(hook_args, event_args)
    Process.wait(
      spawn hook_args.first.miga_variables(
        dataset: name, project: project.path, miga: MiGA::MiGA.root_path,
        object: event_args.first
      )
    )
  end

  ##
  # Pull :dataset_ready hook if preprocessing is complete
  def hook__pull_preprocessing_ready_hooks(_hook_args, _event_args)
    pull_hook(:on_preprocessing_ready) if done_preprocessing?
  end

  ##
  # Dataset Action :pull_result_hooks([], [res])
  # Pull the hook specific to the type of result
  def hook__pull_result_hooks(_hook_args, event_args)
    pull_hook(:"on_result_ready_#{event_args.first}", *event_args)
  end

end
