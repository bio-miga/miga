require_relative 'test_patch'
require 'simplecov'
SimpleCov.start

require 'rubygems'
require 'assertions'
require 'test/unit'
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

module TestHelper
  def teardown
    @tmpdir ||= nil
    FileUtils.rm_rf tmpdir unless @tmpdir.nil?
    ENV['MIGA_HOME'] = nil
  end

  def declare_remote_access
    omit_if(ENV['REMOTE_TESTS'].nil?, 'Remote access is error-prone')
  end

  def declare_forks
    omit_if(!ENV['JRUBY_TESTS'].nil?, 'JRuby doesn\'t implement fork')
  end

  def tmpdir
    @tmpdir ||= Dir.mktmpdir
  end

  def tmpfile(name)
    File.join(tmpdir, name)
  end

  def initialize_miga_home(daemon = '{}')
    ENV['MIGA_HOME'] = tmpdir
    FileUtils.touch(File.join(ENV['MIGA_HOME'], '.miga_rc'))
    File.open(File.join(ENV['MIGA_HOME'], '.miga_daemon.json'), 'w') do |fh|
      fh.puts daemon
    end
  end

  def project(i = 0)
    @project ||= {}
    i = "project#{i}" unless i.is_a? String
    @project[i] ||= MiGA::Project.new(tmpfile(i))
  end

  def dataset(project_i = 0, n = 0)
    n = "dataset#{n}" unless n.is_a? String
    project(project_i).dataset(n) || project(project_i).add_dataset(n)
  end
end
