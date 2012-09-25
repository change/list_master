require 'spec_helper'

describe ListMaster::IntersectMethods do

  before do
    create_everything!
  end

  after do
    destroy_everything!
  end

  describe "#index!" do

    context "after index verification" do
      before do
        ItemListMaster.index!
      end

      it 'should generate a zero priority zset for every attribute value for every declared set without priorty' do
        ItemListMaster.redis.type('category:a').should == 'zset'
        ItemListMaster.redis.type('category:b').should == 'zset'
        ids_and_scores = ItemListMaster.redis.zrange('category:b', 0, -1, {withscores: true}).flatten.map(&:to_i)
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
        ItemListMaster.redis.zrange('assoc_rank', 0, -1, {:withscores => true}).flatten.map(&:to_i).should == [
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

      it "should generate sets with items matching a block for unsorted sets with an if option" do
        ItemListMaster.redis.zrange('value:1', 0, -1).map(&:to_i).to_set.should == Item.where(value: 1).order('created_at DESC').map(&:id).to_set
        ItemListMaster.redis.zrange('value:2', 0, -1).map(&:to_i).to_set.should == Item.where(value: 2).order('created_at DESC').map(&:id).to_set
        ItemListMaster.redis.zrange('value:0', 0, -1).map(&:to_i).to_set.should be_empty
      end

      it "should generate a single set with items that match an if option when using the 'single' options" do
        ItemListMaster.redis.zrange('has_category_b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').order('created_at DESC').map(&:id).to_set
      end
    end

    it "should remove any sets not in the definition and not starting with PROCESSING_PREFIX when finished" do
      ItemListMaster.redis.set :foo, :bar
      ItemListMaster.index!
      ItemListMaster.redis.exists(:foo).should be_false
    end

    it "should not remove any sets starting with PROCESSING_PREFIX when finished" do
      key = "#{ListMaster::IndexMethods::PROCESSING_PREFIX}:foo"
      ItemListMaster.redis.set key, :bar
      ItemListMaster.index!
      ItemListMaster.redis.exists(key).should be_true
    end

  end


end
