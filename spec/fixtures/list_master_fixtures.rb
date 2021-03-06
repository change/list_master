ItemListMaster = ListMaster.define do
  model Item

  scope :has_category

  associated :assoc_items
  associated :multi_items

  set 'recent', :attribute => 'created_at', :descending => true
  set 'attribute_via_method', :attribute => 'attribute_via_method', :descending => true

  set 'assoc_rank', :attribute => 'rank', :on => lambda { |p| p.assoc_items.where('kind IS NULL').first }

  set 'recent_with_category_b', :attribute => 'created_at', :descending => true, :if => lambda { |p| p.category == 'b' }

  set 'category'

  set 'value', :if => lambda { |p| p.value > 0 }

  set 'multi_items', multi: lambda { |i| i.multi_items.map(&:name) }
  set 'has_multi_items', multi: lambda { |i| (1..i.multi_items.length).map(&:to_s) }

  set 'has_category_b', if: lambda { |i| i.category == 'b' }, single: true

end
