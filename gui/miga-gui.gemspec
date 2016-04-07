$:.unshift File.expand_path("../../lib", __FILE__)

require "miga/version"

Gem::Specification.new do |s|
  # Basic information
  s.name	= "miga-gui"
  s.version	= MiGA::MiGA.FULL_VERSION
  s.date	= MiGA::MiGA.VERSION_DATE.to_s
  
  # Metadata
  s.license	= "Artistic-2.0"
  s.summary	= "MiGA GUI"
  s.description = "Graphical User Interface for the Microbial Genomes Atlas"
  s.authors	= ["Luis M. Rodriguez-R"]
  s.email	= "lmrodriguezr@gmail.com"
  s.homepage	= "http://enve-omics.ce.gatech.edu/miga"
  
  # Files
  s.files = Dir[
    "../lib/**/*.rb", "../test/**/*.rb", "img/*", "bin/*",
    "Gemfile", "../Rakefile", "../README.md", "../LICENSE"
  ]
  s.executables	<< "miga"
  
  # Dependencies
  s.add_runtime_dependency "rest-client", "~> 1.7"
  s.add_runtime_dependency "shoes", "4.0.0.pre5"
  s.add_runtime_dependency "daemons", "~> 1.2"
  s.add_runtime_dependency "json", "~> 1.8"
  s.required_ruby_version = "~> 2.0"

  # Docs + tests
  s.add_development_dependency "rake", "~> 11"
  s.add_development_dependency "test-unit", "~> 3"

end
