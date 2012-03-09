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

end

require 'list_master/base'
