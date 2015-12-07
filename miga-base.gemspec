$:.push File.expand_path("lib", File.dirname(__FILE__))
require "miga"

Gem::Specification.new do |s|
   s.name	= "miga-base"
   s.version	= MiGA::MiGA.FULL_VERSION
   s.license	= "artistic 2.0"
   s.summary	= "MiGA"
   s.description = "Microbial Genomes Atlas"
   s.authors	= ["Luis M. Rodriguez-R"]
   s.email	= "lmrodriguezr@gmail.com"
   s.files	= ["lib/miga.rb"]
   s.files	+= Dir["lib/miga/*.rb"]
   s.files	+= Dir["scripts/*.bash"]
   s.files	+= Dir["utils/*"]
   s.files	+= Dir["bin/*"]
   s.files      += Dir["actions/*"]
   s.homepage	= "http://enve-omics.ce.gatech.edu/miga"
   s.executables << "miga"
   s.date	= MiGA::MiGA.VERSION_DATE.to_s
   s.add_runtime_dependency "rest-client", "~> 1.7"
   s.add_runtime_dependency "sqlite3", "~> 1.3"
   s.add_runtime_dependency "daemons", "~> 1.2"
   s.add_runtime_dependency "json", "~> 1.8"
   s.required_ruby_version = "~> 2.0"
end

