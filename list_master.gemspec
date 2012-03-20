lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'list_master/version'

Gem::Specification.new do |s|
  s.name        = "list_master"
  s.version     = ListMaster::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["The I18n Team <3"]
  s.email       = ["tech_ops@change.org"]
  s.homepage    = "http://github.com/change/list_master"
  s.summary     = %q{A redis solution for presenting paginated, scoped lists of models}
  s.description = %q{It is not finished}

  s.files        = Dir.glob("lib/**/*") + %w(README.md)
  s.require_path = 'lib'

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "rails", "~> 3.0.0"
  s.add_dependency "redis"
  s.add_dependency "redis-namespace"

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "sqlite3"
end
