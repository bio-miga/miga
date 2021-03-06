# frozen_string_literal: true

##
# Parallel execution in MiGA.
class MiGA::Parallel < MiGA::MiGA
  class << self
    ##
    # Executes the passed block with the thread number as argument (0-numbered)
    # in +threads+ processes
    def process(threads)
      threads.times do |i|
        Process.fork { yield(i) }
      end
      Process.waitall
    end

    ##
    # Distributes +enum+ across +threads+ and calls the passed block with args:
    # 1. Unitary object from +enum+
    # 2. Index of the unitary object
    # 3. Index of the acting thread
    def distribute(enum, threads)
      process(threads) do |thr|
        enum.each_with_index do |obj, idx|
          yield(obj, idx, thr) if idx % threads == thr
        end
      end
    end
  end
end

