require 'rails/all'
require 'rspec-rails'
require 'sqlite3'

require 'list_master'

require 'fixtures'

ListMaster.redis = Redis.connect :db => 9
ListMaster.redis.flushdb

RSpec.configure do |config|
  config.after(:each) do
    ListMaster.redis.flushdb
  end

  config.after(:suite) do
    FileUtils.rm TEST_DB
  end
end
