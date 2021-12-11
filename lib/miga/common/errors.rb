
module MiGA
  ##
  # A generic MiGA error
  class Error < RuntimeError
  end

  ##
  # An error with a system call
  class SystemCallError < Error
  end
end
