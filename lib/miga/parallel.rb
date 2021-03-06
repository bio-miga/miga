# frozen_string_literal: true

##
# Parallel execution in MiGA.
class MiGA::Parallel < MiGA::MiGA
  class << self
    ##
    # Executes the passed block with the thread number as argument (0-numbered)
    # in +threads+ processes
    def process(threads)
      (0 .. threads - 1).each do |i|
        Process.fork { yield(i) }
      end
      Process.waitall
    end
  end
end

