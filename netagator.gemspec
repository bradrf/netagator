require_relative 'lib/netagator/version'

Gem::Specification.new do |s|
  s.name        = 'netagator'
  s.version     = Netagator::VERSION
  s.summary     = %q{Pure Ruby implementations of network investigation tools.}
  s.description = %q{Pure Ruby implementations of network investigation tools....}

  s.authors = ['Brad Robel-Forrest']
  s.email   = ['brad+netagator@gigglewax.com']
  s.homepage = 'https://github.com/bradrf/netagator'
  s.license  = 'MIT'

  s.files      = `git ls-files`.split("\n")
  s.test_files = s.files.grep(%r{^spec/})

  s.require_paths = ['lib']
  s.required_ruby_version = '>= 1.9.0'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
end
