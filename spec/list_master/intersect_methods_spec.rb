# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleExpectations
describe ListMaster::IntersectMethods do
  before do
    create_everything!
    ItemListMaster.index!
  end

  after do
    destroy_everything!
  end

  describe '#intersect' do
    it 'returns a Struct with members :results, :offset, :limit, :reverse, and :total_entries' do
      expect(ItemListMaster.intersect('recent').members).to eq(%i[results offset limit reverse total_entries])
    end

    it 'results should return an array of ids that are in both lists' do
      expect(ItemListMaster.intersect('recent', 'category:b').results).to eq(
        Item.where(category: 'b').order('created_at DESC').map(&:id),
      )
    end

    it 'results should return an array of ids that are in both lists, reverse sorted' do
      expect(ItemListMaster.intersect('recent', 'category:b', reverse: true).results).to eq(
        Item.where(category: 'b').order('created_at ASC').map(&:id),
      )
    end

    it 'accepts limit and offset' do
      matching = Item.where(category: 'b').order('created_at DESC').map(&:id)
      expect(ItemListMaster.intersect('recent', 'category:b', limit: 2).results).to eq(matching[0, 2])
      expect(ItemListMaster.intersect('recent', 'category:b', offset: 1).results).to eq(
        matching[1, (matching.count - 1)],
      )
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations
