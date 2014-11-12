# encoding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'hammock/version'

Gem::Specification.new do |spec|
  spec.name          = "hammock"
  spec.version       = Hammock::VERSION
  spec.authors       = ["Joshua Davey"]
  spec.email         = ["josh@joshuadavey.com"]
  spec.summary       = %q{Lisp inspired by Clojure}
  spec.description   = %q{Kind of like Clojure, but Rubyish}
  spec.homepage      = "https://github.com/jgdavey/hammock"
  spec.license       = "Eclipse Public License"

  spec.files         = Dir["{lib,spec}/**/*"] + %w[bin/hammock README.md]
  spec.executables   = %w[hammock]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "hamster", "~> 0.4.3"
  spec.add_dependency "atomic", "~> 1.1"

  spec.add_development_dependency "bundler", "~> 1.6"
end
