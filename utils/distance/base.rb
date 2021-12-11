require 'miga'
require 'miga/tax_dist'

class MiGA::DistanceRunner < MiGA::MiGA
  require_relative 'temporal.rb'
  require_relative 'database.rb'
  require_relative 'commands.rb'
  require_relative 'pipeline.rb'

  include MiGA::DistanceRunner::Temporal
  include MiGA::DistanceRunner::Database
  include MiGA::DistanceRunner::Commands
  include MiGA::DistanceRunner::Pipeline
end
