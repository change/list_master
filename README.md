ListMaster
==========

This gem assists with the querying of paginated lists of models that match certain conditions.

For example, given a model:

    ActiveRecord::Schema.define do

      create_table :items do |t|
        t.integer   :power_level
        t.string    :kind
      end

    end

    class Item < ActiveRecord::Base; end

We can define a module with a small DSL:

    ItemListMaster = ListMaster.define do
      model Item

      set :power, :attribute => :power_level
      set :category
    end

Now `ItemListMaster.update_redis_sets!` will put the following sorted sets in redis:

    power                   (items scored by their power_level attribute)
    category:   (all items have zero score)
    category:category_two
    category:category_three (...and so on for any value of category that any item might have)

These sorted sets simply hold ids to the objects that they represent collections of. You can then ask for arrays of ids for items that are in multiple sets:

    ids = ItemListMaster.intersect :power, category: 'category_one'

This returns an `Array` of ids of `Item` objects in category `category_one` ordered by power_level. You could then use the ids in a SQL query for the actual Items:

    Items.where(id: ids)

The two lines above can be shortened to one with ActiveRecord::Relation#list_intersect:

    Item.list_intersect :power, kind: ''

With redis, it's dead simple to slice and dice your sorted sets. Simply supply the options `:limit` and/or `:offset` to `intersect`.

For example, suppose you want a paginated list of `Item`s sorted by `power_level` with 10 per-page, starting at page 1. To obtain the ids for page `x` we would do:

    a.intersect :power, limit: 10, offset: 10*(x-1)

