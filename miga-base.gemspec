$:.unshift File.expand_path('../lib', __FILE__)

require 'miga/version'

Gem::Specification.new do |s|
  # Basic information
  s.name	= 'miga-base'
  s.version	= MiGA::MiGA.FULL_VERSION
  s.date	= MiGA::MiGA.VERSION_DATE.to_s

  # Metadata
  s.license	= 'Artistic-2.0'
  s.summary	= 'MiGA'
  s.description = 'Microbial Genomes Atlas'
  s.authors	= ['Luis M. Rodriguez-R']
  s.email	= 'lmrodriguezr@gmail.com'
  s.homepage	= 'http://enve-omics.ce.gatech.edu/miga'

  # Files
  s.files = Dir[
    'lib/**/*', 'test/**/*.rb', 'lib/miga/_data/**/*',
    'scripts/*.bash', 'utils/**/*', 'bin/*', 'actions/*',
    'Gemfile', 'Rakefile', 'README.md', 'LICENSE'
  ]
  s.executables	<< 'miga'

  # Dependencies
  s.add_runtime_dependency 'daemons', '~> 1.3'
  s.add_runtime_dependency 'json', '~> 2'
  s.add_runtime_dependency 'sqlite3', '~> 1.3'
  s.add_runtime_dependency 'net-http'
  s.add_runtime_dependency 'net-ftp'
  s.required_ruby_version = '>= 2.7'

  # Docs + tests
  s.extra_rdoc_files << 'README.md'
  s.rdoc_options = %w(lib README.md --main README.md)
  s.rdoc_options << '--title' << s.summary
  s.add_development_dependency 'rake', '~> 12'
  s.add_development_dependency 'test-unit', '~> 3'
  s.add_development_dependency 'assertions', '~> 1'
end
