require 'spec_helper'

# Create ActiveRecord models
require 'fixtures'

ItemListMaster = ListMaster.define do
  model Item

  scope :has_category

  associated :assoc_items
  associated :multi_items

  set 'recent',     :attribute => 'created_at', :descending => true
  set 'attribute_via_method', :attribute => 'attribute_via_method', :descending => true

  set 'assoc_rank', :attribute => 'rank', :on => lambda { |p| p.assoc_items.where('kind IS NULL').first }

  set 'recent_with_category_b', :attribute => 'created_at', :descending => true, :on => lambda { |p| (p.category == 'b') ? p : nil }

  set 'category'

  set 'multi_items', multi: lambda { |i| i.multi_items.map(&:name) }
  set 'has_multi_items', multi: lambda { |i| (1..i.multi_items.length).map(&:to_s) }

end

describe ItemListMaster do

  before do
    Item.create! name: 'foo', category: 'a', created_at: 2.months.ago
    Item.create! name: 'bar', category: 'b', created_at: 2.days.ago
    Item.create! name: 'baz', category: 'b', created_at: 30.seconds.ago
    Item.create! name: 'blah'

    AssocItem.create! item: Item.has_category.last, rank: 1, kind: nil
    AssocItem.create! item: Item.has_category.first, rank: 2, kind: 'a'

    MultiItem.create! name: 'one', items: [Item.first]
    MultiItem.create! name: 'two', items: Item.all

  end

  after do
    Item.destroy_all
    AssocItem.destroy_all
    MultiItem.destroy_all
  end

  describe "#index!" do

    before do
      ItemListMaster.index!
    end

    it 'should generate a zero priority zset for every attribute value for every declared set without priorty' do
      ItemListMaster.redis.type('category:a').should == 'zset'
      ItemListMaster.redis.type('category:b').should == 'zset'
      ids_and_scores = ItemListMaster.redis.zrange('category:b', 0, -1, {withscores: true}).map(&:to_i)
      ids_and_scores.select {|x| x != 0}.sort.should == Item.where(category: 'b').map(&:id)
      ids_and_scores.select {|x| x == 0}.count.should == Item.where(category: 'b').count
    end

    it 'should generate a zset for every declared set with priority' do
      ItemListMaster.redis.type('recent').should == 'zset'
      ItemListMaster.redis.zrange('recent', 0, -1).map(&:to_i).should == Item.has_category.order('created_at DESC').map(&:id)
    end

    it 'should generate a zset for every declared set with priority where the attribute is actually an instance method' do
      ItemListMaster.redis.type('attribute_via_method').should == 'zset'
      ItemListMaster.redis.zrange('attribute_via_method', 0, -1).map(&:to_i).should == Item.has_category.sort{|x,y| y.attribute_via_method <=> x.attribute_via_method}.map(&:id)
    end

    it 'should generate a zset for an associated attribute' do
      ItemListMaster.redis.type('assoc_rank').should == 'zset'
      item = Item.all.select {|x| x.assoc_items.where(kind: nil).present? }.first
      ItemListMaster.redis.zrange('assoc_rank', 0, -1, {:withscores => true}).map(&:to_i).should == [
        item.id, item.assoc_items.where(kind: nil).first.rank
      ]
    end

    it 'should remove deleted objects on subsequent calls to index!' do
      Item.first.destroy
      ItemListMaster.index!
      ItemListMaster.redis.zrange('recent', 0, -1).map(&:to_i).should == Item.has_category.order('created_at DESC').map(&:id)
    end

    it 'should remove objects from sorted sets if their attributes change' do
      ItemListMaster.redis.zrange('recent_with_category_b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').order('created_at DESC').map(&:id).to_set
      Item.where(category: 'b').first.destroy
      ItemListMaster.index!
      ItemListMaster.redis.zrange('recent_with_category_b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').order('created_at DESC').map(&:id).to_set
    end

    it 'should remove objects from unsorted sets if their attributes change' do
      ItemListMaster.redis.zrange('category:b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').map(&:id).to_set
      Item.where(category: 'b').first.update_attributes(:category => 'a')
      ItemListMaster.index!
      ItemListMaster.redis.zrange('category:b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').map(&:id).to_set
      ItemListMaster.redis.zrange('category:a', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'a').map(&:id).to_set
    end

    it "should generate sets for items that are in multiple associations via a model attribute" do
      ItemListMaster.redis.zrange('multi_items:one', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| !i.multi_items.all.select { |mi| mi.name == 'one' }.empty? }.map(&:id).to_set
      ItemListMaster.redis.zrange('multi_items:two', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| !i.multi_items.all.select { |mi| mi.name == 'two' }.empty? }.map(&:id).to_set
    end

    it "should generate sets for items that are in multiple associations via an arbitrary block" do
      ItemListMaster.redis.zrange('has_multi_items:1', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| i.multi_items.length >= 1 }.map(&:id).to_set
      ItemListMaster.redis.zrange('has_multi_items:2', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| i.multi_items.length >= 2 }.map(&:id).to_set
    end

    describe "#intersect" do

      it "should return a Struct with members :results, :offset, :limit, :reverse, and :total_entries" do
        ItemListMaster.intersect('recent').members.should == [:results, :offset, :limit, :reverse, :total_entries]
      end

      it 'results should return an array of ids that are in both lists' do
        ItemListMaster.intersect('recent', 'category:b').results.should == Item.where(category: 'b').order('created_at DESC').map(&:id)
      end

      it 'results should return an array of ids that are in both lists, reverse sorted' do
        ItemListMaster.intersect('recent','category:b', reverse: true).results.should == Item.where(category: 'b').order('created_at ASC').map(&:id)
      end

      it 'should accept limit and offset' do
        matching = Item.where(category: 'b').order('created_at DESC').map(&:id)
        ItemListMaster.intersect('recent', 'category:b', :limit => 2).results.should == matching[0, 2]
        ItemListMaster.intersect('recent', 'category:b', :offset => 1).results.should == matching[1,(matching.count() - 1)]
      end
    end
  end
end
