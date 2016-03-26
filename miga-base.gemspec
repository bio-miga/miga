$:.push File.expand_path("lib", File.dirname(__FILE__))

require "miga/version"

Gem::Specification.new do |s|
  # Basic information
  s.name	= "miga-base"
  s.version	= MiGA::MiGA.FULL_VERSION
  s.date	= MiGA::MiGA.VERSION_DATE.to_s
  
  # Metadata
  s.license	= "artistic 2.0"
  s.summary	= "MiGA"
  s.description = "Microbial Genomes Atlas"
  s.authors	= ["Luis M. Rodriguez-R"]
  s.email	= "lmrodriguezr@gmail.com"
  s.homepage	= "http://enve-omics.ce.gatech.edu/miga"
  
  # Files
  s.files = Dir["lib/**/*.rb", "test/**/*.rb",
    "scripts/*.bash", "utils/*", "bin/*", "actions/*",
    "Gemfile", "Rakefile", "README.md", "LICENSE"
  ]
  s.executables	<< "miga"
  
  # Dependencies
  s.add_runtime_dependency "rest-client", "~> 1.7"
  s.add_runtime_dependency "sqlite3", "~> 1.3"
  s.add_runtime_dependency "daemons", "~> 1.2"
  s.add_runtime_dependency "json", "~> 1.8"
  s.required_ruby_version = "~> 2.0"

  # Docs + tests
  s.has_rdoc = true
  s.extra_rdoc_files << "README.md"
  s.rdoc_options = %w(lib README.md --main README.md)
  s.rdoc_options << "--title" << s.summary
  s.add_development_dependency "rake"
  s.add_development_dependency "test-unit"

end
