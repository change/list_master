require 'spec_helper'

describe ListMaster do

  describe "#redis" do

    it 'should return a redis namespace' do
      ListMaster.redis.class.should == Redis::Namespace
      ListMaster.redis.ping.should_not be_empty

      ListMaster.redis.set 'foo', 'bar'
      ListMaster.redis.get('foo').should be_eql 'bar'
    end

    it 'should use the set namespace for redis when its defined' do
      ExampleListMaster = ListMaster.define do
        # just an empty list master
      end
      ExampleListMaster.redis.namespace.should eql('example_list_master')
      ExampleListMaster = ListMaster.define do
        namespace "foo_bar_batz"
      end
      ExampleListMaster.redis.namespace.should eql('foo_bar_batz')
      ExampleListMaster = nil
    end

    it 'sets the remove_sets constant to false if defined' do
      ExampleListMaster = ListMaster.define do
        remove_sets false
      end
      ExampleListMaster.instance_variable_get(:@remove_sets).should be_falsey
    end

  end

end
