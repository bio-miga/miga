
class MiGA::Result < MiGA::MiGA
  class << self
    def RESULT_DIRS
      @@RESULT_DIRS ||=
        MiGA::Dataset.RESULT_DIRS.merge(MiGA::Project.RESULT_DIRS)
    end
  end
end

module MiGA::Result::Base
end

