#!/usr/bin/env ruby

require_relative 'distance/runner.rb'

dataset = ARGV.shift
project = ARGV.shift
opts = Hash[ARGV.map { |i| i.split("=", 2).tap { |j| j[0] = j[0].to_sym } }]
runner = MiGA::DistanceRunner.new(dataset, project, opts)
runner.go!
