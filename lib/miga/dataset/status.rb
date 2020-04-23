##
# Helper module including specific functions for dataset status
module MiGA::Dataset::Status
  ##
  # Returns the status of the dataset. If the status is not yet defined,
  # it recalculates it and, if +save+ is true, saves it in metadata.
  # Return values are:
  # - +:inactive+ The dataset is currently inactive
  # - +:incomplete+ The dataset is not yet fully processed
  # - +:complete+ The dataset is fully processed
  def status(save = false)
    recalculate_status(save) if metadata[:status].nil?
    metadata[:status].to_sym
  end

  ##
  # Identify the current status instead of relying on metadata, and save
  # it if +save+ is true. Return codes are the same as +status+.
  def recalculate_status(save = true)
    metadata[:status] =
      !active? ? :inactive : done_preprocessing? ? :complete : :incomplete
    self.save if save
    metadata[:status].to_sym
  end
end
