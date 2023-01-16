
module MiGA
  ##
  # A generic MiGA error
  class Error < RuntimeError
  end

  ##
  # An error with a system call
  class SystemCallError < Error
  end

  ##
  # An error with remote data
  class RemoteDataError < Error
  end

  ##
  # An error caused by missing remote data
  class RemoteDataMissingError < RemoteDataError
  end
end
