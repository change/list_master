# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleExpectations
describe ListMaster do
  describe '#redis' do
    it 'returns a redis namespace' do
      expect(described_class.redis.class).to eq(Redis::Namespace)
      described_class.redis.ping.should_not be_empty

      described_class.redis.set('foo', 'bar')
      expect(described_class.redis.get('foo')).to eq('bar')
    end

    it 'uses the class as the namespace for redis by default' do
      stub_const('ExampleListMaster', described_class.define {})
      expect(ExampleListMaster.redis.namespace).to eq('example_list_master')
    end

    it 'uses the set namespace for redis when its defined' do
      stub_const(
        'ExampleListMaster',
        described_class.define do
          namespace 'foo_bar_batz'
        end,
      )
      expect(ExampleListMaster.redis.namespace).to eq('foo_bar_batz')
    end

    it 'sets the remove_sets constant to false if defined' do
      stub_const(
        'ExampleListMaster',
        described_class.define do
          remove_sets false
        end,
      )
      expect(ExampleListMaster.instance_variable_get(:@remove_sets)).to be_falsey
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations
