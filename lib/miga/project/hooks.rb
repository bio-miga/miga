require 'miga/common/hooks'

##
# Helper module including specific functions to handle project hooks.
# Supported events:
# - on_create(): When created
# - on_load(): When loaded
# - on_save(): When saved
# - on_add_dataset(dataset): When a dataset is added, with name +dataset+
# - on_unlink_dataset(dataset): When dataset with name +dataset+ is unlinked
# - on_result_ready(result): When any result is ready, with key +result+
# - on_result_ready_{result}(): When +result+ is ready
# - on_processing_ready(): When preprocessing is complete
# Supported hooks:
# - run_lambda(lambda, args...)
# - run_cmd(cmd)
# Internal hooks:
# - _pull_result_hooks()
module MiGA::Project::Hooks
  include MiGA::Common::Hooks

  def default_hooks
    {
      on_result_ready: [[:_pull_result_hooks]]
    }
  end

  ##
  # Run +cmd+ in the command-line with {{variables}}:
  # project, project_name, miga, object (if defined by the event)
  # - +hook_args+: +[cmd]+
  # - +event_args+: +[object (optional)]+
  def hook_run_cmd(hook_args, event_args)
    Process.wait(
      spawn hook_args.first.miga_variables(
        project: path, project_name: name,
        miga: MiGA::MiGA.root_path, object: event_args.first
      )
    )
  end

  ##
  # Dataset Action :pull_result_hooks([], [res])
  # Pull the hook specific to the type of result
  def hook__pull_result_hooks(_hook_args, event_args)
    pull_hook(:"on_result_ready_#{event_args.first}", *event_args)
    pull_hook(:on_processing_ready) if next_task(nil, false).nil?
  end
end
