module Support

  def create_everything!
    create_items!
    create_assoc_items!
    create_multi_items!
  end

  def destroy_everything!
    Item.destroy_all
    AssocItem.destroy_all
    MultiItem.destroy_all
  end

  private

  def create_items!
    Item.create! name: 'foo', category: 'a', created_at: 2.months.ago
    Item.create! name: 'bar', category: 'b', created_at: 2.days.ago
    Item.create! name: 'baz', category: 'b', created_at: 30.seconds.ago
    Item.create! name: 'blah'
  end

  def create_assoc_items!
    AssocItem.create! item: Item.has_category.last, rank: 1, kind: nil
    AssocItem.create! item: Item.has_category.first, rank: 2, kind: 'a'
  end

  def create_multi_items!
    MultiItem.create! name: 'one', items: [Item.first]
    MultiItem.create! name: 'two', items: Item.all
  end

end
