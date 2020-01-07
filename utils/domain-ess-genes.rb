#!/usr/bin/env ruby

esslog = ARGV.shift
outlog = ARGV.shift
domain = ARGV.shift

def quality(hsh)
  q = {}
  q[:found] = hsh.values.map{ |i| i==0 ? 0 : 1 }.inject(:+)
  q[:multi] = hsh.values.map{ |i| i==0 ? 0 : i-1 }.inject(:+)
  q[:cmp] = 100.0*q[:found].to_f/hsh.size
  q[:cnt] = 100.0*q[:multi].to_f/hsh.size
  q
end

# Find collection and detected anomalies
cnt_ref = {}
at = :header
collection = 'dupont_2012'
File.open(esslog, 'r') do |fh|
  fh.each_line do |ln|
    v = ln.chomp.gsub(/^! +/, '')
    if v == 'Multiple copies: '
      at = :multi
    elsif v == 'Missing genes: '
      at = :missing
    elsif v =~ /Collection: (\S+)/
      collection = $1
    elsif at == :multi
      v =~ /^(\d+) (\S+): .*/ or raise "Unexpected multi-copies format: #{v}"
      cnt_ref[$2] = $1.to_i
    elsif at == :missing
      v =~ /^(\S+): .*/ or raise "Unexpected missing format: #{v}"
      cnt_ref[$1] = 0
    end
  end
end

# Find expected genes for domain
n_dom = Hash[
  `HMM.essential.rb -L -q '-#{domain}' -c '#{collection}'`
    .chomp.split("\n").map { |i| i.split("\t") }
]
l_dom = n_dom.keys
cnt_dom = {}
l_dom.each { |i| cnt_dom[i] = cnt_ref[i] || 1 }

#  Correct report
q = quality(cnt_dom)
File.open(outlog, 'w') do |ofh|
  ofh.puts "! Collection: #{collection} #{domain}"
  ofh.puts "! Essential genes found: #{q[:found]}/#{cnt_dom.size}."
  ofh.puts "! Completeness: #{q[:cmp].round(1)}%."
  ofh.puts "! Contamination: #{q[:cnt].round(1)}%."
  if q[:multi] > 0
    ofh.puts "! Multiple copies: "
    cnt_dom.each{ |k,v| ofh.puts "!   #{v} #{k}: #{n_dom[k]}." if v>1 }
  end
  if q[:found] < cnt_dom.size
    ofh.puts "! Missing genes: "
    cnt_dom.each{ |k,v| ofh.puts "!   #{k}: #{n_dom[k]}." if v==0 }
  end
end
