# frozen_string_literal: true

require 'rspec'
require 'list_master'

require 'support'
require 'fixtures/active_record_fixtures'
require 'fixtures/list_master_fixtures'

# Configure ListMaster
ListMaster.redis = Redis.new(db: 9)

# Get fresh db on every test
RSpec.configure do |config|
  config.include Support

  config.before do
    ListMaster.redis.flushdb
  end

  config.after(:suite) do
    ListMaster.redis.flushdb
  end
end
