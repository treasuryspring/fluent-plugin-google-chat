# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "fluent-plugin-google-chat"
  gem.description = "fluent Google Chat plugin"
  gem.homepage    = "https://github.com/treasuryspring/fluent-plugin-google-chat"
  gem.license     = "Apache-2.0"
  gem.summary     = gem.description
  gem.version     = File.read("VERSION").strip
  gem.authors     = ["Lionel Gabaude"]
  gem.email       = ["tech@treasuryspring.com"]
  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "fluentd", ">= 0.12.0"
  gem.add_dependency "googleauth"
  gem.add_dependency "google-api-client", "~> 0.34"

  gem.add_development_dependency "rake", ">= 10.1.1"
  gem.add_development_dependency "rr", ">= 1.0.0"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "pry-nav"
  gem.add_development_dependency "test-unit", "~> 3.0.2"
  gem.add_development_dependency "test-unit-rr", "~> 1.0.3"
  gem.add_development_dependency "dotenv"
end
