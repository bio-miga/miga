require 'simplecov'
SimpleCov.start

require 'rubygems'
require 'test/unit'
require 'assertions'
require 'miga/common'
require 'stringio'

##
# Kernel extensions tp capture +$stdout+ and +$stderr+ based on
# http://thinkingdigitally.com/archive/capturing-output-from-puts-in-ruby/
module Kernel

  def capture_stdout
    out = StringIO.new
    $stdout = out
    yield
    return out
  ensure
    $stdout = STDOUT
  end

  def capture_stderr
    err = StringIO.new
    $stderr = err
    yield
    return err
  ensure
    $stderr = STDERR
  end

end
