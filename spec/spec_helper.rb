require 'rspec'
require 'list_master'

require 'support'
require 'fixtures/active_record_fixtures'
require 'fixtures/list_master_fixtures'

# Configure ListMaster
ListMaster.redis = Redis.connect :db => 9

# Get fresh db on every test
RSpec.configure do |config|

  config.include Support

  config.before(:each) do
    ListMaster.redis.redis.flushdb
  end

  config.after(:suite) do
    ListMaster.redis.redis.flushdb
  end
end
