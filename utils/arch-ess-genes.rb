#!/usr/bin/env ruby

esslog = ARGV.shift
outlog = ARGV.shift
l_all = `HMM.essential.rb -l -q`.chomp.split("\n").map{ |i| i.gsub(/\t.*/,"") }
n_arc = Hash[
  `HMM.essential.rb -l -q -A`.chomp.split("\n").map{ |i| i.split("\t") }
]
l_arc = n_arc.keys

def quality(hsh)
  q = {}
  q[:found] = hsh.values.map{ |i| i==0 ? 0 : 1 }.inject(:+)
  q[:multi] = hsh.values.map{ |i| i==0 ? 0 : i-1 }.inject(:+)
  q[:cmp] = 100.0*q[:found].to_f/hsh.size
  q[:cnt] = 100.0*q[:multi].to_f/hsh.size
  q
end

cnt_ref = {}
l_all.each{ |i| cnt_ref[i] = 1 }

at = :header
File.open(esslog, "r") do |fh|
  fh.each_line do |ln|
    v = ln.chomp.gsub(/^! +/, "")
    if v=="Multiple copies: "
      at = :multi
    elsif v=="Missing genes: "
      at = :missing
    elsif at==:multi
      v =~ /^(\d+) (\S+): .*/ or raise "Unexpected multi-copies format: #{v}"
      cnt_ref[$2] = $1.to_i
    elsif at==:missing
      v =~ /^(\S+): .*/ or raise "Unexpected missing format: #{v}"
      cnt_ref[$1] = 0
    end
  end
end

cnt_arc = {}
l_arc.each{ |i| cnt_arc[i] = cnt_ref[i] }

q = quality(cnt_arc)
File.open(outlog, "w") do |ofh|
  ofh.puts "! Essential genes found: #{q[:found]}/#{cnt_arc.size}."
  ofh.puts "! Completeness: #{q[:cmp].round(1)}%."
  ofh.puts "! Contamination: #{q[:cnt].round(1)}%."
  if q[:multi] > 0
    ofh.puts "! Multiple copies: "
    cnt_arc.each{ |k,v| ofh.puts "!   #{v} #{k}: #{n_arc[k]}." if v>1 }
  end
  if q[:found] < cnt_arc.size
    ofh.puts "! Missing genes: "
    cnt_arc.each{ |k,v| ofh.puts "!   #{k}: #{n_arc[k]}." if v==0 }
  end
end
