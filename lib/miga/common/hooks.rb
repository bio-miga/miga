##
# Helper module including specific functions to handle dataset hooks.
module MiGA::Common::Hooks
  ##
  # Call the hook with symbol +event+ and any parameters +event_args+
  def pull_hook(event, *event_args)
    event = event.to_sym
    event_queue = (hooks[event] || [])
    event_queue += (metadata[event] || []) if respond_to? :metadata
    event_queue.each do |i|
      action = i.first
      hook_name = :"hook_#{action}"
      hook_args = i[1..-1]
      if respond_to? hook_name
        MiGA::MiGA.DEBUG "Hook: #{self.class}(#{event} > #{action})"
        self.send(hook_name, hook_args, event_args)
      else
        raise "Cannot find action #{action} elicited by #{self.class}(#{event})"
      end
    end
  end

  ##
  # Whenever +event+ occurs, launch +action+ with parameters +args+.
  def add_hook(event, action, *args)
    (hooks[event] ||= []) << [action, *args]
  end

  ##
  # Get the stack of hooks
  def hooks
    @_hooks ||= default_hooks
  end

  ##
  # Default object's hooks
  def default_hooks
    {}
  end

  ##
  # Run the function defined in the first hook argument
  def hook_run_lambda(hook_args, event_args)
    hook_args.first[*event_args]
  end
end
