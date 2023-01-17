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
    self.class.EXCLUDE_NOREF_TASKS.include?(task) && !ref?
  end

  ##
  # Ignore +task+ because it's not a multi dataset
  def ignore_multi?(task)
    self.class.ONLY_MULTI_TASKS.include?(task) && !multi?
  end

  ##
  # Ignore +task+ because it's not a nonmulti dataset
  def ignore_nonmulti?(task)
    self.class.ONLY_NONMULTI_TASKS.include?(task) && !nonmulti?
  end
end