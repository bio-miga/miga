require "rake/testtask"

SOURCES = FileList["lib/**/*.rb"]

desc "Default Task"
task :default => "test:all"

desc "All tests"
Rake::TestTask.new("test:all") do |t|
  t.libs << "test"
  t.pattern = "test/*_test.rb"
  t.verbose = true
end

desc "JRuby tests"
Rake::TestTask.new("test:jruby") do |t|
  ENV["JRUBY_TESTS"] = "true"
  t.libs << "test"
  t.pattern = "test/*_test.rb"
  t.verbose = true
end
