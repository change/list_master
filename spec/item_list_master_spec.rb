require 'spec_helper'

ItemListMaster = ListMaster.define do
  model Item

  scope :has_category

  set 'recent', :attribute => 'created_at', :descending => true
  set 'assoc_rank', :attribute => 'rank', :on => lambda { |p| p.assoc_items.where('kind IS NULL').first }

  set 'category'
  set 'monthly', :where => lambda { |i| i.created_at.to_time > 30.days.ago and i.created_at.to_time < 1.days.ago }

  set 'multi_items', multi: lambda { |mi| mi.name }
end

describe ItemListMaster do

  before do
    Item.destroy_all
    Item.create! name: 'foo', category: 'a', created_at: 2.months.ago
    Item.create! name: 'bar', category: 'b', created_at: 2.days.ago
    Item.create! name: 'baz', category: 'b', created_at: 30.seconds.ago
    Item.create! name: 'blah'

    AssocItem.create! item_id: 3, rank: 1, kind: nil
    AssocItem.create! item_id: 1, rank: 2, kind: 'a'

    MultiItem.create! name: 'one', items: [Item.first]
    MultiItem.create! name: 'two', items: Item.all

    @master = ItemListMaster
  end

  describe "#process" do

    before do
      @master.process
    end

    it 'should generate a zero priority zset for every attribute value for every declared set without priorty' do
      @master.redis.type('category:a').should == 'zset'
      @master.redis.type('category:b').should == 'zset'
      ids_and_scores = @master.redis.zrange('category:b', 0, -1, {withscores: true}).map(&:to_i)
      ids_and_scores.select {|x| x != 0}.sort.should == Item.where(category: 'b').map(&:id)
      ids_and_scores.select {|x| x == 0}.count.should == Item.where(category: 'b').count
    end

    it 'should generate a zset for every declared set with priority' do
      @master.redis.type('recent').should == 'zset'
      @master.redis.zrange('recent', 0, -1).map(&:to_i).should == Item.has_category.order('created_at DESC').map(&:id)
    end

    it 'should generate a zset for an associated attribute' do
      @master.redis.type('assoc_rank').should == 'zset'
      item = Item.all.select {|x| x.assoc_items.where(kind: nil).present? }.first
      @master.redis.zrange('assoc_rank', 0, -1, {:withscores => true}).map(&:to_i).should == [
        item.id, item.assoc_items.where(kind: nil).first.rank
      ]
    end

    it 'should generate a zet for every set declared with where' do
      @master.redis.type('monthly').should == 'zset'
      in_month = Item.where("created_at > '#{30.days.ago.to_s(:db)}' AND created_at < '#{1.days.ago.to_s(:db)}'")
      @master.redis.zrange('monthly', 0, -1, {:withscores => true}).map(&:to_i).should == [in_month.first.id, 0]
    end

    it 'should remove deleted objects on subsequent calls to process' do
      Item.destroy(1)
      @master.process
      @master.redis.zrange('recent', 0, -1).map(&:to_i).should == Item.has_category.order('created_at DESC').map(&:id)
    end

    it 'should remove objects from sets if their attributes change' do
      @master.redis.zrange('category:b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').map(&:id).to_set
      Item.where(category: 'b').first.update_attributes(:category => 'a')
      @master.process
      @master.redis.zrange('category:b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').map(&:id).to_set
      @master.redis.zrange('category:a', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'a').map(&:id).to_set
    end

    it "should generate sets for items that are in multiple associations" do
      @master.redis.zrange('multi_items:one', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| !i.multi_items.all.select { |mi| mi.name == 'one' }.empty? }.map(&:id).to_set
      @master.redis.zrange('multi_items:two', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| !i.multi_items.all.select { |mi| mi.name == 'two' }.empty? }.map(&:id).to_set
    end


    describe "#intersect" do

      it 'should return an array of ids that are in both lists' do
        @master.intersect('recent', 'category:b').should == Item.where(category: 'b').order('created_at DESC').map(&:id)
      end

      it 'should accept limit and offset' do
        matching = Item.where(category: 'b').order('created_at DESC').map(&:id)
        @master.intersect('recent', 'category:b', :limit => 2).should == matching[0, 2]
        @master.intersect('recent', 'category:b', :offset => 1).should == matching[1,(matching.count() - 1)]
      end

    end

  end

end
