# frozen_string_literal: true

require 'miga/result'
require 'miga/dataset/base'
require 'miga/common/with_result'

# This library is only required by +#cleanup_distances!+, so it is now
# being loaded on call instead to allow most of miga-base to work without
# issue in systems with problematic SQLite3 installations.
# require 'miga/sqlite'

##
# Helper module including specific functions to add dataset results
module MiGA::Dataset::Result
  include MiGA::Dataset::Base
  include MiGA::Common::WithResult

  require 'miga/dataset/result/ignore'
  require 'miga/dataset/result/add'
  include MiGA::Dataset::Result::Ignore
  include MiGA::Dataset::Result::Add

  ##
  # Return the basename for results
  def result_base
    name
  end

  ##
  # Returns the key symbol of the first registered result (sorted by the
  # execution order). This typically corresponds to the result used as the
  # initial input. Passes +save+ to #add_result.
  def first_preprocessing(save = false)
    @first_processing ||= @@PREPROCESSING_TASKS.find do |t|
      !add_result(t, save).nil?
    end
  end

  ##
  # Returns the key symbol of the next task that needs to be executed or nil.
  # Passes +save+ to #add_result.
  def next_preprocessing(save = false)
    first_preprocessing(save) if save
    next_task(nil, save)
  end

  ##
  # Are all the dataset-specific tasks done? Passes +save+ to #add_result
  def done_preprocessing?(save = false)
    !first_preprocessing(save).nil? && next_preprocessing(save).nil?
  end

  ##
  # Returns an array indicating the stage of each task (sorted by execution
  # order). The values are integers:
  # - 0 for an undefined result (a task before the initial input).
  # - 1 for a registered result (a completed task).
  # - 2 for a queued result (a task yet to be executed).
  # It passes +save+ to #add_result
  def profile_advance(save = false)
    # Determine the start point
    first_task = first_preprocessing(save)
    return Array.new(self.class.PREPROCESSING_TASKS.size, 0) if first_task.nil?

    # Traverse all tasks
    adv, state, next_task = [[], 0, next_preprocessing(save)]
    self.class.PREPROCESSING_TASKS.each do |task|
      state = 1 if first_task == task
      state = 2 if !next_task.nil? && next_task == task
      adv << state
    end

    # Return advance array
    return adv
  end

  ##
  # Returns a Hash with tasks as key and status as value.
  # See +result_status+ for possible values
  def results_status
    Hash[@@PREPROCESSING_TASKS.map { |task| [task, result_status(task)] }]
  end

  ##
  # Returns the status of +task+. The status values are symbols:
  # - -: the task is upstream from the initial input
  # - ignore_*: the task is to be ignored, see codes in #why_ignore
  # - complete: a task with registered results
  # - pending: a task queued to be performed
  def result_status(task)
    reason = why_ignore(task)
    case reason
    when :upstream then :-
    when :execute  then :pending
    when :complete then :complete
    else; :"ignore_#{reason}"
    end
  end

  ##
  # Clean-up all the stored distances, removing values for datasets no longer in
  # the project as reference datasets.
  def cleanup_distances!
    return if get_result(:distances).nil?

    require 'miga/sqlite'
    ref = project.datasets.select(&:ref?).select(&:active?).map(&:name)
    %i[haai aai ani].each do |metric|
      cleanup_distances_by_metric!(ref, metric)
    end
  end

  private

  ##
  # Cleanup the tables of a specific +metric+ (symbol) removing all values
  # against dataset names not in +ref+ (Array of string)
  def cleanup_distances_by_metric!(ref, metric)
    db_type = :"#{metric}_db"
    db = get_result(:distances).file_path(db_type)
    return if db.nil? || !File.size?(db)

    sqlite_db = MiGA::SQLite.new(db)
    table = db_type[-6..-4]
    val = sqlite_db.run("select seq2 from #{table}")
    return if val.empty?

    (val.map(&:first) - ref).each do |extra|
      sqlite_db.run("delete from #{table} where seq2=?", extra)
    end
  end

end
