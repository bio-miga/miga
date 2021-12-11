require 'zlib'
require 'miga'

class MiGA::SubcladeRunner < MiGA::MiGA
  require_relative 'temporal.rb'
  require_relative 'pipeline.rb'

  include MiGA::SubcladeRunner::Temporal
  include MiGA::SubcladeRunner::Pipeline
end
