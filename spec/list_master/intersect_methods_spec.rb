require 'spec_helper'

describe ListMaster::IntersectMethods do

  before do
    create_everything!
    ItemListMaster.index!
  end

  after do
    destroy_everything!
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
