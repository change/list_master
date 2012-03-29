# -*- encoding: utf-8 -*-
require File.expand_path('../lib/list_master/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "list_master"
  gem.version     = ListMaster::VERSION

  gem.authors     = ["The I18n Team <3"]
  gem.email       = ["tech_ops@change.org"]
  gem.summary     = %q{A redis solution for presenting paginated, scoped lists of models}
  gem.description = %q{It is not finished}
  gem.homepage    = "http://github.com/change/list_master"
  gem.license     = 'MIT'

  gem.files       = `git ls-files`.split("\n").grep(%r{^\w})
  gem.test_files  = gem.files.grep(%r{^spec/})
  gem.extra_rdoc_files = %w(README.md LICENSE)

  gem.add_dependency "activerecord", "~> 3.0.0"
  gem.add_dependency "redis"
  gem.add_dependency "redis-namespace"

  gem.required_rubygems_version = ">= 1.3.6"
end
