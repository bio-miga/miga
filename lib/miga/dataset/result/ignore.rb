# frozen_string_literal: true

module MiGA::Dataset::Result::Ignore
  ##
  # Should I ignore +task+ for this dataset?
  def ignore_task?(task)
    why_ignore(task) != :execute
  end

  ##
  # Returns an array of symbols indicating all the possible reasons why a
  # given task migh be ignored:
  # - empty: the dataset has no data
  # - inactive: the dataset is inactive
  # - upstream: the task is upstream from dataset's input
  # - force: forced to ignore by metadata
  # - project: incompatible project
  # - noref: incompatible dataset, only for reference
  # - multi: incompatible dataset, only for multi
  # - nonmulti: incompatible dataset, only for nonmulti
  # - complete: the task is already complete
  def ignore_reasons
    %i[empty inactive upstream force project noref multi nonmulti complete]
  end

  ##
  # Return a code explaining why a task is ignored (see +ignore_reasons+) or
  # the symbol +:execute+ (do not ignore, execute the task)
  def why_ignore(task)
    # Find a reason to ignore it
    ignore_reasons.each do |i|
      return i if send(:"ignore_#{i}?", task)
    end

    # Otherwise, execute
    return :execute
  end

  ##
  # Ignore +task+ because it's already done
  def ignore_complete?(task)
    !get_result(task).nil?
  end

  ##
  # Ignore any task because the dataset is inactive (+_task+ is ignored)
  def ignore_inactive?(_task)
    !active?
  end

  ##
  # Ignore any task because the dataset is empty (+_task+ is ignored)
  def ignore_empty?(_task)
    first_preprocessing.nil?
  end

  ##
  # Ignore +task+ because it's upstream from the entry point
  def ignore_upstream?(task)
    self.class.PREPROCESSING_TASKS.index(task) <
      self.class.PREPROCESSING_TASKS.index(first_preprocessing)
  end

  ##
  # Ignore +task+ because the metadata says so
  def ignore_force?(task)
    !(metadata["run_#{task}"].nil? || metadata["run_#{task}"])
  end

  ##
  # Ignore +task+ because the project is not compatible
  def ignore_project?(task)
    task == :taxonomy && project.option(:ref_project).nil?
  end

  ##
  # Ignore +task+ because it's not a reference dataset
  def ignore_noref?(task)
    ignore_by_type?(task, :noref)
  end

  ##
  # Ignore +task+ because it's not a multi dataset
  def ignore_multi?(task)
    ignore_by_type?(task, :multi)
  end

  ##
  # Ignore +task+ because it's not a nonmulti dataset
  def ignore_nonmulti?(task)
    ignore_by_type?(task, :nonmulti)
  end

  ##
  # Ignore +task+ by +type+ of dataset, one of: +:noref+, +:multi+, or
  # +:nonmulti+
  def ignore_by_type?(task, type)
    return false if force_task?(task)

    test, list =
      case type.to_sym
      when :noref
        [:ref?, self.class.EXCLUDE_NOREF_TASKS]
      when :multi
        [:multi?, self.class.ONLY_MULTI_TASKS]
      when :nonmulti
        [:nonmulti?, self.class.ONLY_NONMULTI_TASKS]
      else
        raise "Unexpected error, unknown type reason: #{type}"
      end

    list.include?(task) && !send(test)
  end

  ##
  # Force the +task+ to be executed even if it should otherwise be
  # ignored due to reasons: +:noref+, +:multi+, or +:nonmulti+. Other
  # reasons to ignore a task are not affected by metadata forcing
  def force_task?(task)
    !!metadata["run_#{task}"]
  end
end
