#!/usr/bin/env ruby

abort "
Usage:
#{$0} {FastA file} {MyTaxa file} {Data output}

" if ARGV[2].nil?

faa, mytaxa, outdata = ARGV
winsize = 10

ids = File.open(faa).grep(/^>/).map{|dl| dl.chomp.sub(/^>/,'').sub(/\s.*/,'')}
tax = Hash[ids.map{|k| [k, "NA"]}]

k, l = nil
File.open(mytaxa).each do |ln|
   ln.chomp!
   if $.%2 == 1
      k, l = ln.split /\t/
   else
      tax[k] = ln.gsub(/<[^>]+>/,'').gsub(/;/,'::')
   end
end

all_tax = tax.values.uniq.sort{|x,y| tax.values.count(y) <=> tax.values.count(x) }

c = []
c << all_tax.map{|t| tax.values.count(t) }
n_wins = (ids.size/winsize).ceil
(0 .. (n_wins-1)).each do |win|
   k = ids[win*winsize, winsize]
   win_t = tax.values_at(*k)
   c << all_tax.map{|t| win_t.count(t)}
end
p = c.map{|col| col.map{|cell| cell.to_f/col.inject(:+)}}

fh = File.open(outdata, 'w')
fh.puts "# Data derived from #{mytaxa}, with #{winsize}-genes windows"
fh.puts "# " + (['Tax-label', 'Genome'] + (1 .. n_wins).map{|i| "Win_#{i}"}).join("\t")
(0 .. (all_tax.size - 1)).each do |row|
   fh.puts ([all_tax[row]] + p.map{|col| col[row]}).join "\t"
end
fh.close

