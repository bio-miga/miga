##
# Helper module including specific functions for dataset type
module MiGA::Dataset::Type
  ##
  # Get the type of dataset as Symbol
  def type
    metadata[:type]
  end

  ##
  # Is this dataset known to be multi-organism?
  def multi?
    self.class.KNOWN_TYPES.dig(type, :multi)
  end

  ##
  # Is this dataset known to be single-organism?
  def nonmulti?
    y = self.class.KNOWN_TYPES.dig(type, :multi)
    y.nil? ? nil : !y
  end

  ##
  # Are universal marker genes expected to be found in this dataset?
  def markers?
    self.class.KNOWN_TYPES.dig(type, :markers)
  end

  ##
  # Check that the dataset type is defined, known, and compatible with the
  # project type and raise an exception if any of these checks fail
  #
  # If the dataset type is +:empty+, it returns +false+ without raising an
  # exception, and true otherwise (and no tests are failed)
  def check_type
    raise MiGA::Error.new('Undefined dataset type') unless type
    return false if type == :empty

    unless self.class.KNOWN_TYPES[type]
      raise MiGA::Error.new("Unknown dataset type: #{type}")
    end
    unless self.class.KNOWN_TYPES[type][:project_types].include? project.type
      raise MiGA::Error.new(
        "Dataset type (#{type}) incompatible with project (#{project.type})"
      )
    end

    true
  end

end
