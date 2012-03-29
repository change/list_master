require 'active_record'

#
# Create in-memory SQLite3 database
#
ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

#
# Load schema
#
ActiveRecord::Schema.define do
  create_table :people do |t|
    t.string   :name
    t.date     :date_of_birth
    t.string   :city
    t.integer  :salary
  end

  create_table :pets do |t|
    t.integer  :person_id
    t.string   :species
    t.integer  :value
  end

  create_table :cars do |t|
    t.string   :kind
    t.string   :color
  end

  create_table :people_cars, id: false do |t|
    t.integer  :person_id,    null: false
    t.integer  :car_id,       null: false
  end
end


#
# Models
#
class Person < ActiveRecord::Base
  has_many :pets
  has_and_belongs_to_many :cars
end

class Pet < ActiveRecord::Base
  belongs_to :person
end

class Car < ActiveRecord::Base
  has_and_belongs_to_many :persons
end

#
# Create/destroy fixtures around every example
#
# RSpec.configure do |config|
#   config.around :each do |example|
#     Item.create! name: 'foo', type: 'a', created_at: 2.months.ago
#     Item.create! name: 'bar', type: 'b', created_at: 2.days.ago
#     Item.create! name: 'baz', type: 'b', created_at: 30.seconds.ago
#     Item.create! name: 'blah'

#     AssocItem.create! item: Item.last, rank: 1, kind: nil
#     AssocItem.create! item: Item.first, rank: 2, kind: 'a'

#     MultiAssocItem.create! name: 'one', items: [Item.first]
#     MultiAssocItem.create! name: 'two', items: Item.all

#     example.run

#     Item.destroy_all
#     AssocItem.destroy_all
#     MultiAssocItem.destroy_all
#   end
# end
