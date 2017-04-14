#!/usr/bin/env ruby

require "miga"
require "sqlite3"

p = MiGA::Project.load(ARGV[0])
raise "Impossible to load project: #{ARGV[0]}." if p.nil?

File.unlink(ARGV[1]) if File.exist? ARGV[1]
db = SQLite3::Database.new(ARGV[1])
db.execute "create table metadata(" +
  "`name` varchar(256), `field` varchar(256), `value` text)"

def searchable(db, k, v)
  db.execute "insert into metadata values(?,?,?)",
    k.to_s, " #{v.to_s.downcase.gsub(/[^A-Za-z0-9\-]+/, " ")} "
end

p.each_dataset do |name, d|
  next unless d.is_ref?
  searchable(db, :name, d.name)
  d.metadata.each do |k, v|
    next if [:created, :updated].include? k
    v = v.sorted_ranks.map{ |r| r[1] }.join(" ") if k==:tax
    searchable(db, k, v)
  end
end

