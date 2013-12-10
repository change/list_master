require 'redis'
require 'redis-namespace'

require 'list_master/dsl'
require 'list_master/index_methods'
require 'list_master/intersect_methods'

module ListMaster

  extend self

  # Accepts a Redis object
  def redis=(redis)
    @redis = Redis::Namespace.new :list_master, :redis => redis
  end

  # Returns the current Redis connection. If none has been created, create default
  def redis
    return @redis if @redis
    self.redis = Redis.connect
    self.redis
  end

  def define &block
    dsl = ListMaster::Dsl.new
    dsl.instance_eval &block

    Module.new do
      self.extend ListMaster::IndexMethods, ListMaster::IntersectMethods
      %w(@model @scope @sets @associations @namespace @remove_sets).each do |iv|
        self.instance_variable_set(iv, dsl.instance_variable_get(iv))
      end

      # This instance's redis namespace
      def self.redis
        redis_namespace = @namespace || self.name.underscore
        @redis ||= Redis::Namespace.new redis_namespace, :redis => ListMaster.redis
      end
    end
  end

end
