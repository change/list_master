require 'redis'
require 'redis-namespace'

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
    dsl.instance_exec &block

    Module.new do
      extend ListMaster::Base

      @model       = dsl.instance_variable_get("@model")
      @scope       = dsl.instance_variable_get("@scope")
      @sets        = dsl.instance_variable_get("@sets")
      @associations = dsl.instance_variable_get("@associations")
    end
  end

end

require 'list_master/base'
require 'list_master/dsl'
