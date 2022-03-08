# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleExpectations
describe ListMaster::IndexMethods do
  before do
    create_everything!
  end

  after do
    destroy_everything!
  end

  describe '#index!' do
    context 'with index verification' do
      before do
        ItemListMaster.index!
      end

      it 'generates a zero priority zset for every attribute value for every declared set without priorty' do
        expect(ItemListMaster.redis.type('category:a')).to eq('zset')
        expect(ItemListMaster.redis.type('category:b')).to eq('zset')

        ids_and_scores = ItemListMaster.redis.zrange('category:b', 0, -1, { withscores: true }).flatten.map(&:to_i)
        expect(ids_and_scores.reject { |x| x == 0 }.sort).to eq(Item.where(category: 'b').map(&:id))
        expect(ids_and_scores.select { |x| x == 0 }.count).to eq(Item.where(category: 'b').count)
      end

      it 'generates a zset for every declared set with priority' do
        expect(ItemListMaster.redis.type('recent')).to eq('zset')
        expect(ItemListMaster.redis.zrange('recent', 0, -1).map(&:to_i)).to eq(
          Item.has_category.order('created_at DESC').map(&:id),
        )
      end

      it 'generates a zset for every declared set with priority where the attribute is actually an instance method' do
        expect(ItemListMaster.redis.type('attribute_via_method')).to eq('zset')
        expect(ItemListMaster.redis.zrange('attribute_via_method', 0, -1).map(&:to_i)).to eq(
          Item.has_category.sort { |x, y| y.attribute_via_method <=> x.attribute_via_method }.map(&:id),
        )
      end

      it 'generates a zset for an associated attribute' do
        expect(ItemListMaster.redis.type('assoc_rank')).to eq('zset')
        item = Item.all.select { |x| x.assoc_items.where(kind: nil).present? }.first
        ranked_order = ItemListMaster.redis.zrange('assoc_rank', 0, -1, { withscores: true }).flatten.map(&:to_i)
        expect(ranked_order).to eq(
          [
            item.id,
            item.assoc_items.where(kind: nil).first.rank,
          ],
        )
      end

      it 'removes deleted objects on subsequent calls to index!' do
        Item.first.destroy
        ItemListMaster.index!
        expect(ItemListMaster.redis.zrange('recent', 0, -1).map(&:to_i)).to eq(
          Item.has_category.order('created_at DESC').map(&:id),
        )
      end

      it 'removes objects from sorted sets if their attributes change' do
        expect(ItemListMaster.redis.zrange('recent_with_category_b', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(category: 'b').order('created_at DESC').map(&:id).to_set,
        )

        Item.where(category: 'b').first.destroy
        ItemListMaster.index!

        expect(ItemListMaster.redis.zrange('recent_with_category_b', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(category: 'b').order('created_at DESC').map(&:id).to_set,
        )
      end

      it 'removes objects from unsorted sets if their attributes change' do
        expect(ItemListMaster.redis.zrange('category:b', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(category: 'b').map(&:id).to_set,
        )

        Item.where(category: 'b').first.update(category: 'a')
        ItemListMaster.index!

        expect(ItemListMaster.redis.zrange('category:b', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(category: 'b').map(&:id).to_set,
        )
        expect(ItemListMaster.redis.zrange('category:a', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(category: 'a').map(&:id).to_set,
        )
      end

      it 'generates sets for items that are in multiple associations via a model attribute' do
        expect(ItemListMaster.redis.zrange('multi_items:one', 0, -1).map(&:to_i).to_set).to eq(
          Item.has_category.reject { |i| i.multi_items.load.select { |mi| mi.name == 'one' }.empty? }
                           .map(&:id)
                           .to_set,
        )
        expect(ItemListMaster.redis.zrange('multi_items:two', 0, -1).map(&:to_i).to_set).to eq(
          Item.has_category.reject { |i| i.multi_items.load.select { |mi| mi.name == 'two' }.empty? }
                           .map(&:id)
                           .to_set,
        )
      end

      it 'generates sets for items that are in multiple associations via an arbitrary block' do
        expect(ItemListMaster.redis.zrange('has_multi_items:1', 0, -1).map(&:to_i).to_set).to eq(
          Item.has_category.select { |i| i.multi_items.length >= 1 }.map(&:id).to_set,
        )
        expect(ItemListMaster.redis.zrange('has_multi_items:2', 0, -1).map(&:to_i).to_set).to eq(
          Item.has_category.select { |i| i.multi_items.length >= 2 }.map(&:id).to_set,
        )
      end

      it 'generates sets with items matching a block for unsorted sets with an if option' do
        expect(ItemListMaster.redis.zrange('value:1', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(value: 1).order('created_at DESC').map(&:id).to_set,
        )
        expect(ItemListMaster.redis.zrange('value:2', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(value: 2).order('created_at DESC').map(&:id).to_set,
        )
        expect(ItemListMaster.redis.zrange('value:0', 0, -1).map(&:to_i).to_set).to be_empty
      end

      it "generates a single set with items that match an if option when using the 'single' options" do
        expect(ItemListMaster.redis.zrange('has_category_b', 0, -1).map(&:to_i).to_set).to eq(
          Item.where(category: 'b').order('created_at DESC').map(&:id).to_set,
        )
      end
    end

    it 'removes any sets not in the definition and not starting with PROCESSING_PREFIX when finished' do
      ItemListMaster.redis.set(:foo, :bar)
      ItemListMaster.index!
      expect(ItemListMaster.redis.exists(:foo)).to eq(0)
    end

    it 'does not remove any sets that are not in the definition if remove_sets is set to false' do
      ItemListMaster.redis.set :foo, :bar
      ItemListMaster.instance_variable_set(:@remove_sets, false)
      ItemListMaster.index!
      expect(ItemListMaster.redis.exists(:foo)).to eq(1)
      ItemListMaster.instance_variable_set(:@remove_sets, true)
    end

    it 'does not remove any sets starting with PROCESSING_PREFIX when finished' do
      key = "#{ListMaster::IndexMethods::PROCESSING_PREFIX}:foo"
      ItemListMaster.redis.set key, :bar
      ItemListMaster.index!
      expect(ItemListMaster.redis.exists(key)).to eq(1)
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations
