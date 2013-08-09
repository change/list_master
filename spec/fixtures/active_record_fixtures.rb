require 'active_record'

#
# Create db and table
#
ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

ActiveRecord::Schema.define do
  create_table :items do |t|
    t.string :name
    t.string :category
    t.integer :value

    t.timestamps
  end

  create_table :assoc_items do |t|
    t.integer :item_id
    t.integer :rank
    t.string :kind
  end

  create_table :multi_items do |t|
    t.string :name
  end

  create_table :items_multi_items, id: false do |t|
    t.integer :item_id,          null: false
    t.integer :multi_item_id,    null: false
  end
end


#
# An example model
#
class Item < ActiveRecord::Base
  has_many :assoc_items
  has_and_belongs_to_many :multi_items

  scope :has_category, -> { where('category IS NOT NULL') }

  def attribute_via_method
    @attribute_via_method ||= created_at.to_i
  end

end

class AssocItem < ActiveRecord::Base
  belongs_to :item
end

class MultiItem < ActiveRecord::Base
  has_and_belongs_to_many :items
end
