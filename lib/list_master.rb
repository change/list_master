require 'redis'
require 'redis-namespace'

module ListMaster

  ##
  # Accepts a Redis object
  ##
  def self.redis=(redis)
    @redis = Redis::Namespace.new :list_master, :redis => redis
  end

  ##
  # The namespace to be used for all ListMaster redis keys.
  # Each model that uses define_list_master also gets their
  # own namespace underneath this one.
  ##
  def self.redis
    return @redis if @redis
    self.redis = Redis.connect
    self.redis
  end

end

require 'active_record'

require 'list_master/definition'
require 'list_master/indexer'
require 'list_master/intersection'

ActiveRecord::Base.extend ListMaster::Definition
ActiveRecord::Base.extend ListMaster::Indexer
ActiveRecord::Base.extend ListMaster::Intersection
