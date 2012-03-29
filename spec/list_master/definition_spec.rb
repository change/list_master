require 'spec_helper'
require 'fixtures'

describe ListMaster::Definition do

  describe "a model calling list_master with a block" do

    let(:model){
      Class.new(ActiveRecord::Base) do
        list_master do
          sequences {
            date_of_birth
            poorest         attribute: :salary, descending: true
            richest         attribute: :salary
            best_pets       attribute: lambda { |p| p.pets.map(&:value).max }
          }

          filters {
            city
            has_pet         binary: lambda { |p| p.pets.count > 0 }
            car_color       multi:  lambda { |p| p.cars.map(&:color) }
          }

          scope :not_lower_class
          associated :pets
          associated :cars
          scope :not_upper_class
        end

        def self.name
          "ExampleModel"
        end
      end
    }

    describe "further calls to list_master without a block" do

      it "should return a hash with appropriate keys" do
        model.list_master.should be_an_instance_of Hash
        model.list_master.keys.to_set.should == [:sequences, :filters, :scoping, :associations, :redis].to_set
      end

    end
  end
end
