# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'timeseries/version'

Gem::Specification.new do |spec|
  spec.name          = "timeseries"
  spec.version       = Timeseries::VERSION
  spec.authors       = ["Nick O'Neill"]
  spec.email         = ["mr.nick.oneill@gmail.com"]
  spec.description   = "A time series gem used by StartupStats apps"
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/Holler/timeseries"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0"
end
