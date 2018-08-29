#!/usr/bin/env ruby

require_relative 'subclade/runner.rb'

project = ARGV.shift
step = ARGV.shift
opts = Hash[ ARGV.map{ |i| i.split("=",2).tap{ |j| j[0] = j[0].to_sym } } ]
runner = MiGA::SubcladeRunner.new(project, step, opts)
runner.go!
