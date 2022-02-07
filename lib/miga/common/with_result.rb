##
# Helper module including specific functions to handle objects that
# have results. The class including this module must implement methods
# +.RESULT_DIRS+, +#ignore_task?+, +#metadata+, +#project+,
# and +#inactivate!+.
module MiGA::Common::WithResult
  ##
  # Result directories as a Hash
  def result_dirs
    self.class.RESULT_DIRS
  end

  ##
  # Look for the result with symbol key +task+ and register it in the object.
  # If +save+ is false, it doesn't register the result, but it still returns a
  # result if it already exists.
  #
  # The +opts+ hash controls result creation (if necessary).
  # Supported values include:
  # - +is_clean+: A Boolean indicating if the input files are clean
  # - +force+: A Boolean indicating if the result must be re-indexed,
  #   ignored unless +save = true+
  #
  # Returns MiGA::Result or nil
  def add_result(task, save = true, opts = {})
    task = task.to_sym
    return nil if result_dirs[task].nil?

    base = File.join(project.path, 'data', result_dirs[task], result_base)
    json = "#{base}.json"
    return MiGA::Result.load(json) unless save

    MiGA::Result.create(json, opts[:force]) do
      r = send("add_result_#{task}", base, opts) if File.exist?("#{base}.done")
      unless r.nil?
        r.save
        pull_hook(:on_result_ready, r.key)
      end
    end
  end

  ##
  # Get the result MiGA::Result in this object identified by the symbol +task+
  def result(task)
    task = task.to_sym
    return nil if result_dirs[task].nil?

    MiGA::Result.load(
      "#{project.path}/data/#{result_dirs[task]}/#{result_base}.json"
    )
  end

  ##
  # Get all the results (Array of MiGA::Result) in this object
  def results
    result_dirs.keys.map { |k| result k }.compact
  end

  ##
  # For each result execute the 2-ary block: key symbol and MiGA::Result
  def each_result
    results.each { |res| yield(res.key, res) }
  end

  ##
  # Get a result as MiGA::Result for the object with key +task+.
  # This is equivalent to +add_result(task, false)+.
  def get_result(task)
    add_result(task, false)
  end

  ##
  # Get the next task from +tasks+, saving intermediate results if +save+.
  # If +tasks+ is +nil+ (default), it uses the entire list of tasks.
  # Returns a Symbol.
  def next_task(tasks = nil, save = false)
    tasks ||= result_dirs.keys
    tasks.find do |t|
      if ignore_task?(t)
        # Do not run if this step is to be ignored
        false
      else
        res = add_result(t, save)
        if res.nil?
          # Run if the step has not been calculated,
          # unless too many attempts were already made
          cur_try = metadata["_try_#{t}"] || 0
          if cur_try > project.option(:max_try)
            inactivate! "Too many errors in step #{t}"
            false
          else
            true
          end
        else
          # Run if the step is ready but has to be recalculated
          res.recalculate? ? true : false
        end
      end
    end
  end

  ##
  # Mark all results for recalculation
  def recalculate_tasks(reason = nil)
    each_result { |_k, res| res.recalculate!(reason).save }
  end

end
