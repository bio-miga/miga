# frozen_string_literal: true

##
# Parallel execution in MiGA.
class MiGA::Parallel < MiGA::MiGA
  class << self
    ##
    # Executes the passed block with the thread number as argument (0-numbered)
    # in +threads+ processes
    def process(threads)
      threads.times
        .map { |i| Process.fork { yield(i) } }
        .map { |pid| Process.waitpid2(pid) }
    end

    ##
    # Distributes +enum+ across +threads+ and calls the passed block with args:
    # 1. Unitary object from +enum+
    # 2. Index of the unitary object
    # 3. Index of the acting thread
    def distribute(enum, threads, &blk)
      process(threads) { |thr| thread_enum(enum, threads, thr, &blk) }
    end

    ##
    # Enum through +enum+ executing the passed block only for thread with index
    # +thr+, one of +threads+ threads. The passed block has the same arguments
    # as the one in +#distribute+
    def thread_enum(enum, threads, thr)
      enum.each_with_index do |obj, idx|
        yield(obj, idx, thr) if idx % threads == thr
      end
    end

    ##
    # Assesses the success of all thread exit codes and raises an error if
    # any of the children status in +status+ failed. It can be used as:
    #
    #   status = MiGA::Parallel.process(3) { |i| 1/i }
    #   MiGA::Parallel.assess_success(status)
    # 
    # Or in conjunction with +MiGA::Parallel.distribute+
    def assess_success(status)
      failed = status.map { |i| i[1].success? ? 0 : 1 }.inject(:+)
      return if failed.zero?

      raise MiGA::Error.new(
        "Child threads failed: #{failed}/#{status.size}. " \
        "Maximum exit status: #{status.map { |i| i[1].exitstatus || 0 }.max}"
      )
    end
  end
end
