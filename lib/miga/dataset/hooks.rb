require 'miga/common/hooks'

##
# Helper module including specific functions to handle dataset hooks.
# Supported events:
# - on_create(): When first created
# - on_load(): When loaded
# - on_save(): When saved
# - on_remove(): When removed
# - on_activate(): When activated
# - on_inactivate(): When inactivated
# - on_result_ready(result): When any result is ready, with key +result+
# - on_result_ready_{result}(): When +result+ is ready
# - on_preprocessing_ready(): When preprocessing is complete
# Supported hooks:
# - run_lambda(lambda, args...)
# - recalculate_status()
# - check_type()
# - clear_run_counts()
# - run_cmd(cmd)
# Internal hooks:
# - _pull_result_hooks()
module MiGA::Dataset::Hooks
  include MiGA::Common::Hooks

  ##
  # Dataset hooks triggered by default
  def default_hooks
    {
      on_create: [[:recalculate_status]],
      on_save: [[:check_type]],
      on_activate: [[:clear_run_counts], [:recalculate_status]],
      on_inactivate: [[:recalculate_status]],
      on_result_ready: [[:_pull_result_hooks]],
      on_preprocessing_ready: [[:clear_run_counts], [:recalculate_status]],
    }
  end

  ##
  # Clear metadata from run counts
  def hook_clear_run_counts(_hook_args, _event_args)
    metadata
      .data.keys
      .select { |k| k.to_s =~ /^_try_/ }
      .each { |k| metadata[k] = nil }
    metadata[:_step] = nil
    save
  end

  ##
  # Recalculate the dataset status and save in metadata
  def hook_recalculate_status(_hook_args, _event_args)
    recalculate_status
  end

  ##
  # Ensure that the dataset type exists and is compatible with the project type
  def hook_check_type(_hook_args, _event_args)
    check_type
  end

  ##
  # Run +cmd+ in the command-line with {{variables}}:
  # dataset, project, project_name, miga, object (if defined for the event)
  # - +hook_args+: +[cmd]+
  # - +event_args+: +[object (optional)]+
  def hook_run_cmd(hook_args, event_args)
    Process.wait(
      spawn hook_args.first.miga_variables(
        dataset: name, project: project.path, project_name: project.name,
        miga: MiGA::MiGA.root_path, object: event_args.first
      )
    )
  end

  ##
  # Dataset Action :pull_result_hooks([], [res])
  # Pull the hook specific to the type of result
  def hook__pull_result_hooks(_hook_args, event_args)
    pull_hook(:"on_result_ready_#{event_args.first}", *event_args)
    pull_hook(:on_preprocessing_ready) if done_preprocessing?
  end
end
