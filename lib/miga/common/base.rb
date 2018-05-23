
class MiGA::MiGA
  
  # Class-level
  class << self
    ##
    # Turn on debugging.
    def DEBUG_ON ; @@DEBUG=true end

    ##
    # Turn off debugging.
    def DEBUG_OFF ; @@DEBUG=false end

    ##
    # Turn on debug tracing (and debugging).
    def DEBUG_TRACE_ON
      @@DEBUG_TRACE=true
      DEBUG_ON()
    end

    ##
    # Turn off debug tracing (but not debugging).
    def DEBUG_TRACE_OFF
      @@DEBUG_TRACE=false
    end

    ##
    # Send debug message.
    def DEBUG(*args)
      $stderr.puts(*args) if @@DEBUG
      $stderr.puts(
            caller.map{ |v| v.gsub(/^/,'     ') }.join("\n") ) if @@DEBUG_TRACE
    end
  end

end

module MiGA::Common

  ##
  # Should debugging information be reported?
  @@DEBUG = false

  ##
  # Should the trace of debugging information be reported?
  @@DEBUG_TRACE = false

end

