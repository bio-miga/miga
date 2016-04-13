require "rake/testtask"

SOURCES = FileList["lib/**/*.rb"]

desc "Default Task"
task :default => "test:base"

desc "Base Tests"
Rake::TestTask.new("test:base") do |t|
  t.libs << "test"
  t.pattern = "test/[^j]*_test.rb"
  t.verbose = true
end

desc "GUI Tests"
Rake::TestTask.new("test:gui") do |t|
  ENV["GUI_TESTS"] = "true"
  t.libs << "test"
  t.libs << "test"
  t.pattern = "test/j*_test.rb"
  t.verbose = true
end

desc "All the tests"
Rake::TestTask.new("test:all") do |t|
  ENV["GUI_TESTS"] = "true"
  t.libs << "test"
  t.libs << "test"
  t.pattern = "test/*_test.rb"
  t.verbose = true
end
