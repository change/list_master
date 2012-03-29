require 'spec_helper'
require 'fixtures'

class Item
  define_list_master do

    sequences {
      recent      attribute: :created_at, :descending => true
      assoc_rank, attribute: lambda { |i| i.assoc_items.select{ |ai| ai.kind.nil? }.first.rank }
    }

    filters {
      category
      monthly binary: lambda { |i| i.created_at.to_time > 30.days.ago and i.created_at.to_time < 1.days.ago }
      named   multi:  lambda { |i| i.multi_items.map(&:name) }
    }

    scope :has_category

    associated :assoc_items
    associated :multi_items
  end
end

describe Item do

  category :type


  multi_category :multi_assoc_items, joins(:multi_assoc_items).select(:name)

end

module ItemListMaster; end

describe ItemListMaster do

  describe "#process" do

    before do
      Item::ListMaster.process
    end

    it 'should generate a zero priority zset for every attribute value for every declared set without priorty' do
      Item::ListMaster.redis.type('category:a').should == 'zset'
      Item::ListMaster.redis.type('category:b').should == 'zset'
      ids_and_scores = Item::ListMaster.redis.zrange('category:b', 0, -1, {withscores: true}).map(&:to_i)
      ids_and_scores.select {|x| x != 0}.sort.should == Item.where(category: 'b').map(&:id)
      ids_and_scores.select {|x| x == 0}.count.should == Item.where(category: 'b').count
    end

    it 'should generate a zset for every declared set with priority' do
      Item::ListMaster.redis.type('recent').should == 'zset'
      Item::ListMaster.redis.zrange('recent', 0, -1).map(&:to_i).should == Item.has_category.order('created_at DESC').map(&:id)
    end

    it 'should generate a zset for an associated attribute' do
      Item::ListMaster.redis.type('assoc_rank').should == 'zset'
      item = Item.all.select {|x| x.assoc_items.where(kind: nil).present? }.first
      Item::ListMaster.redis.zrange('assoc_rank', 0, -1, {:withscores => true}).map(&:to_i).should == [
        item.id, item.assoc_items.where(kind: nil).first.rank
      ]
    end

    it 'should generate a zet for every set declared with where' do
      Item::ListMaster.redis.type('monthly').should == 'zset'
      in_month = Item.where("created_at > '#{30.days.ago.to_s(:db)}' AND created_at < '#{1.days.ago.to_s(:db)}'")
      Item::ListMaster.redis.zrange('monthly', 0, -1, {:withscores => true}).map(&:to_i).should == [in_month.first.id, 0]
    end

    it 'should remove deleted objects on subsequent calls to process' do
      Item.first.destroy
      Item::ListMaster.process
      Item::ListMaster.redis.zrange('recent', 0, -1).map(&:to_i).should == Item.has_category.order('created_at DESC').map(&:id)
    end

    it 'should remove objects from sets if their attributes change' do
      Item::ListMaster.redis.zrange('category:b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').map(&:id).to_set
      Item.where(category: 'b').first.update_attributes(:category => 'a')
      Item::ListMaster.process
      Item::ListMaster.redis.zrange('category:b', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'b').map(&:id).to_set
      Item::ListMaster.redis.zrange('category:a', 0, -1).map(&:to_i).to_set.should == Item.where(category: 'a').map(&:id).to_set
    end

    it "should generate sets for items that are in multiple associations" do
      ItemListMaster.redis.zrange('multi_assoc_items:one', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| !i.multi_assoc_items.all.select { |mi| mi.name == 'one' }.empty? }.map(&:id).to_set
      ItemListMaster.redis.zrange('multi_assoc_items:two', 0, -1).map(&:to_i).to_set.should == Item.has_category.select { |i| !i.multi_assoc_items.all.select { |mi| mi.name == 'two' }.empty? }.map(&:id).to_set
    end


    describe "#intersect" do

      it 'should return an array of ids that are in both lists' do
        Item::ListMaster.intersect('recent', 'category:b').should == Item.where(category: 'b').order('created_at DESC').map(&:id)
      end

      it 'should accept limit and offset' do
        matching = Item.where(category: 'b').order('created_at DESC').map(&:id)
        Item::ListMaster.intersect('recent', 'category:b', :limit => 2).should == matching[0, 2]
        Item::ListMaster.intersect('recent', 'category:b', :offset => 1).should == matching[1,(matching.count() - 1)]
      end

    end

    describe "#list_intersect" do
      it 'should return Items matching the ids for the given set intersection' do
        arel_query = Item.list_intersection('assoc_rank', 'category:b').arel
        arel_query.ast.orders = []
        Item.find_by_sql(arel_query.to_sql).should == Item.has_category.joins(:assoc_items).order(assoc_items: :rank).where(category: 'b').where('assoc_items.kind IS NULL')
      end
    end
  end
end
