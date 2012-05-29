require 'rspec'
require 'list_master'

# Configure ListMaster
ListMaster.redis = Redis.connect :db => 9

# Get fresh db on every test
RSpec.configure do |config|

  config.before(:each) do
    ListMaster.redis.flushdb
  end

  config.after(:suite) do
    ListMaster.redis.flushdb
  end
end
