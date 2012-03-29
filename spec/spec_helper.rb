require 'rspec'
require 'list_master'

ListMaster.redis = Redis.connect :db => 9

RSpec.configure do |config|

  config.before :each do
    ListMaster.redis.flushdb
  end

  config.after :suite do
    ListMaster.redis.flushdb
  end
end
