
require 'miga/result/base'

##
# Helper module including functions to access the source of results
module MiGA::Result::Source

  ##
  # Load and return the source (parent object) of a result
  def source
    @source ||= if MiGA::Project.RESULT_DIRS[key]
      project
    else
      project.dataset(File.basename(path, '.json'))
    end
  end

  ##
  # Detect the result key assigned to this result
  def key
    @key ||= if relative_dir == 'data/90.stats' && file_path(:metadata_index)
      :project_stats
    else
      MiGA::Result.RESULT_DIRS.find do |k, v|
        "data/#{v}" == relative_dir
      end.first
    end
  end

  ##
  # Path of the result containing the directory relative to the parent project
  def relative_dir
    @relative_dir ||= dir.sub("#{project_path}/", '')
  end

  ##
  # Path of the result's JSON definition relative to the parent project
  def relative_path
    @relative_path ||= path.sub("#{project_path}/", '')
  end

  ##
  # Project containing the result
  def project
    @project ||= MiGA::Project.load(project_path)
  end

  ##
  # Path to the project containing the result. In most cases this should be
  # identical to +project.path+, but this function is provided for safety,
  # so the path referencing is identical to that of +self.path+ whenever they
  # need to be compared.
  def project_path
    path[ 0 .. path.rindex('/data/') - 1 ]
  end
end

