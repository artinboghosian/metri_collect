# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'metri_collect/version'

Gem::Specification.new do |spec|
  spec.name          = "metri_collect"
  spec.version       = MetriCollect::VERSION
  spec.authors       = ["Artin Boghosian", "Stephen Roos"]
  spec.email         = ["aboghosian@careerarc.com", "sroos@careerarc.com"]

  spec.homepage      = "https://github.com/CareerArcGroup/metri_collect"
  spec.license       = "MIT"
  spec.summary       = %q{A framework for publishing application metrics}
  spec.description   = %q{MetriCollect is a Ruby framework that provides a common interface with which to collect, publish, and monitor application metrics.}

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "log4r", "~> 1.1"   # for the log4r publisher
  spec.add_runtime_dependency "aws-sdk-cloudwatch", "~> 1"   # for the cloudwatch publisher

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5"
end
