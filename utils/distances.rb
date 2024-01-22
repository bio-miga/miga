#!/usr/bin/env ruby

require_relative 'distance/runner.rb'

project = ARGV.shift
dataset = ARGV.shift
opts = Hash[ARGV.map { |i| i.split('=', 2).tap { |j| j[0] = j[0].to_sym } }]
runner = MiGA::DistanceRunner.new(project, dataset, opts)
runner.go!
