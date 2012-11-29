# -*- encoding: utf-8 -*-
require File.expand_path('../lib/list_master/version', __FILE__)

Gem::Specification.new do |s|
  s.authors     = ['Chase Stubblefield', 'Eric Nicholas', 'Rex Chung', 'Vijay Ramesh']
  s.email       = 'tech_ops@change.org'
  s.summary     = %q(A redis solution for presenting paginated, scoped lists of models)
  s.homepage    = 'http://github.com/change/list_master'

  s.name          = 'list_master'
  s.files         = `git ls-files`.split($\)
  s.require_paths = ['lib']
  s.test_files    = s.files.grep(/^spec/)
  s.version       = ListMaster::VERSION

  s.platform = Gem::Platform::RUBY
  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'activerecord', '>= 3'
  s.add_dependency 'redis', '~> 3.0'
  s.add_dependency 'redis-namespace'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'debugger'
  s.add_development_dependency 'rake'
end
