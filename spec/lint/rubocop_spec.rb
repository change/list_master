# frozen_string_literal: true

require 'spec_helper'
require 'rubocop'

RSpec.describe RuboCop do
  it 'passes' do
    path = File.expand_path('../..', __dir__)
    result = RuboCop::CLI.new.run(['-f', 'simple', path])
    expect(result).to eq(0)
  end
end
