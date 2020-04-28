##
# Helper module including specific functions for dataset status
module MiGA::Dataset::Status
  ##
  # Returns the status of the dataset. If the status is not yet defined,
  # it recalculates it and, if +save+ is true, saves it in metadata.
  # Return symbols are:
  # - +:inactive+ The dataset is currently inactive
  # - +:incomplete+ The dataset is not yet fully processed
  # - +:complete+ The dataset is fully processed
  def status(save = false)
    recalculate_status(save) if metadata[:status].nil?
    metadata[:status].to_sym
  end

  ##
  # Identify the current status and save it if +save+ and the status changed.
  # Return symbols are the same as +status+.
  def recalculate_status(save = true)
    old_status = metadata[:status]
    metadata[:status] =
      !active? ? 'inactive' : done_preprocessing? ? 'complete' : 'incomplete'
    self.save if save && !old_status.nil? && old_status != metadata[:status]
    metadata[:status].to_sym
  end
end
