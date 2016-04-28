#!/usr/bin/env ruby

# @package MiGA
# @license Artistic-2.0

o = {}
opts = OptionParser.new do |opt|
  opt_banner(opt)
  opt_common(opt, o)
end.parse!

##=> Main <=
opts.parse!
puts Time.now.to_s
