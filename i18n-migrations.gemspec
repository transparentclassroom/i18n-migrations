# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'i18n/migrations/version'

Gem::Specification.new do |spec|
  spec.name          = "i18n-migrations"
  spec.version       = I18n::Migrations::VERSION
  spec.authors       = ["Jeremy Lightsmith"]
  spec.email         = ["jeremy.lightsmith@gmail.com"]

  spec.summary       = %q{Migrations for doing i18n.}
  spec.description   = %q{We help you manage your locale translations with migrations, just the way Active Record helps you manage your db with migrations.}
  spec.homepage      = "https://github.com/transparentclassroom/i18n-migrations"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  # spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.executables   = ["i18n-migrate"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ['>= 2.4']

  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec_junit_formatter"

  spec.add_dependency 'google_drive'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'faraday'
  spec.add_dependency 'colorize'
end
