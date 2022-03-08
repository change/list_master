# frozen_string_literal: true

require File.expand_path('lib/list_master/version', __dir__)

Gem::Specification.new do |s|
  s.authors     = ['Chase Stubblefield', 'Eric Nicholas', 'Rex Chung', 'Vijay Ramesh']
  s.email       = 'tech_ops@change.org'
  s.summary     = 'A redis solution for presenting paginated, scoped lists of models'
  s.homepage    = 'http://github.com/change/list_master'

  s.name          = 'list_master'
  s.files         = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
  s.require_paths = ['lib']
  s.test_files    = s.files.grep(/^spec/)
  s.version       = ListMaster::VERSION

  s.platform = Gem::Platform::RUBY

  s.required_ruby_version = Gem::Requirement.new('>= 2.6')

  s.add_dependency 'activerecord', '>= 3'
  s.add_dependency 'redis'
  s.add_dependency 'redis-namespace'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec_junit_formatter'
  s.add_development_dependency 'sqlite3'
end
