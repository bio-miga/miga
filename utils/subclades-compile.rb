#!/usr/bin/env ruby

$:.push File.expand_path(File.dirname(__FILE__) + "/lib")
dir = ARGV.shift
out = ARGV.shift or abort "Usage: #{$0} <classif.dir> <out.base>"

def read_classif(dir, classif={})
   classif_file = File.expand_path("miga-project.classif", dir)
   return classif unless File.exist? classif_file
   File.size?(File.expand_path('miga-project.ready', dir)) or
         raise "Incomplete recursion found at #{dir}"
   fh = File.open(classif_file, "r")
   klass = []
   while ln = fh.gets
      r = ln.chomp.split("\t")
      classif[r[0]] ||= []
      classif[r[0]] << r[1]
      klass[r[1].to_i] = r[1]
   end
   fh.close
   klass.each do |i|
      d = File.expand_path("miga-project.sc-#{i}", dir)
      classif = read_classif(d, classif) if Dir.exist? d
   end
   classif
end

def print_tree(classif, col=0)
   klass = classif.values.map{ |i| i[col] }.compact.uniq
   if klass.size<=1
      o = classif.keys
   else
      o = klass.map do |c|
	 oo = print_tree(classif.select{ |k,v| v[col]==c }, col+1)
	 "#{oo}[#{c}]" unless oo.nil?
      end.compact
   end
   o.size==0 ? nil :
      o.size==1 ? o[0] :
      "(#{o.join(",")})"
end

c = read_classif(dir)
max_depth = c.values.map{|i| i.count}.max
File.open("#{out}.tsv", 'w') do |fh|
  c.each { |k,v| fh.puts ([k] + v + ["0"]*(max_depth-v.count)).join("\t") }
end
File.open("#{out}.nwk", 'w') { |fh| fh.puts print_tree(c) + ";" }
