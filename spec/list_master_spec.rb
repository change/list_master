# frozen_string_literal: true

require 'spec_helper'

describe ListMaster do
  describe '#redis' do
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
