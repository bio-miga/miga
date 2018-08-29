
require 'tmpdir'

module MiGA::SubcladeRunner::Temporal

  # Create the empty temporal structure
  def create_temporals
  end

  # Path to the +file+ in the temporal directory
  def tmp_file(file)
    File.expand_path(file, tmp)
  end
end
