require 'rake/testtask'

SOURCES = FileList['lib/**/*.rb']

desc 'Default Task'
task :default => 'test:all'

desc 'Default tests'
task :test => 'test:all'

namespace :test do
  desc 'All tests'
  Rake::TestTask.new(:all) do |t|
    t.libs << 'test'
    t.pattern = 'test/*_test.rb'
    t.verbose = true
  end

  FileList['test/*_test.rb'].each do |i|
    b = File.basename(i, '_test.rb')
    desc "Test #{b}"
    Rake::TestTask.new(:"#{b}") do |t|
      t.libs << 'test'
      t.pattern = i
      t.verbose = true
    end
  end
end
