require 'spec_helper'

class ItemListMaster < ListMaster::Base
  model Item

  set 'recent', :attribute => 'created_at', :descending => true
  set 'category'
  set 'assoc_rank', :attribute => 'rank', :on => lambda { |p| p.assoc_items.where('kind IS NULL').first }

  set 'monthly', :where => lambda { |i| i.created_at.to_time > 30.days.ago and i.created_at.to_time < 1.days.ago }
end

describe ItemListMaster do

  before do
    @master = ItemListMaster.new
  end

  describe "#process" do

    before do
      @master.process
    end

    it 'should generate a zero priority zset for every attribute value for every declared set without priorty' do
      @master.redis.type('category:a').should == 'zset'
      @master.redis.type('category:b').should == 'zset'
      @master.redis.zrange('category:b', 0, -1).map(&:to_i).to_set.should == Set.new([2, 3])
      @master.redis.zscore('category:b', 2).to_i.should == 0
      @master.redis.zscore('category:b', 3).to_i.should == 0
    end

    it 'should generate a zset for every declared set with priority' do
      @master.redis.type('recent').should == 'zset'
      @master.redis.zrange('recent', 0, -1).map(&:to_i).should == [3, 2, 1]
    end

    it 'should generate a zset for an associated attribute' do
      @master.redis.type('assoc_rank').should == 'zset'
      @master.redis.zrange('assoc_rank', 0, -1, {:withscores => true}).map(&:to_i).should == [
        3,
        1
      ]
    end

    it 'should generate a zet for every set declared with where' do
      @master.redis.type('monthly').should == 'zset'
      @master.redis.zrange('monthly', 0, -1, {:withscores => true}).map(&:to_i).should == [2, 0]
    end

    describe "#intersect" do

      it 'should return an array of ids that are in both lists' do
        @master.intersect('recent', 'category:b').should == [3, 2]

        @master.intersect('assoc_rank', 'category:a').should == []
      end

      it 'should accept limit and offset' do
        @master.intersect('recent', 'category:b', :limit => 1, :offset => 1).should == [2]
      end

    end

  end

end
