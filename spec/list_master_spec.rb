require 'spec_helper'

describe ListMaster do

  describe "#redis" do

    it 'should return a redis namespace' do
      ListMaster.redis.class.should == Redis::Namespace
      ListMaster.redis.ping.should be_present

      ListMaster.redis.set 'foo', 'bar'
      ListMaster.redis.get('foo').should be_eql 'bar'
    end

  end

end
