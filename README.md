ListMaster
==========

This gem assists with the querying of paginated lists of models that match certain conditions.

For example, let's say you have a model Item with attributes `power_level` and `category`. You would define the class for this as follows:

    class ItemListMaster < ListMaster::Base
      model 'Item'

      set 'power', :attribute => 'power_level'
      set 'category'
    end

Now when `ItemListMaster.new.process` is called, the following sorted sets will be put in redis:

    power                   (items scored by there 'power_level' attribute)
    category:category_one   (all items have zero score)
    category:category_two
    category:category_three (...and so on for every value of 'category')

These sorted sets simply hold ids to the objects that they represent collections of. You can then ask for arrays of ids for items that are in multiple sets:

    a = ItemListMaster.new
    a.process
    a.intersect 'power', 'category:category_one' #=> Struct {
                                                      :results => Array of ids of Items in 'category_one' ordered by 'power_level',
                                                      :offset => integer,
                                                      :limit => integer,
                                                      :reverse => boolean,
                                                      :total_entries => integer
                                                    }
