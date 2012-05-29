[![Build Status](https://secure.travis-ci.org/change/list_master.png?branch=master)](http://travis-ci.org/change/list_master)

ListMaster
==========

This gem assists with the querying of paginated lists of models that match certain conditions.

For example, let's say you have a model Item with attributes `power_level` and `category`. You would define the module for this as follows:

    ItemListMaster = ListMaster.define do
      model Item

      set 'power', :attribute => 'power_level'
      set 'category'
    end

Now when `ItemListMaster.index!` is called, the following sorted sets will be put in redis:

    power                   (items scored by there 'power_level' attribute)
    category:a   (all items have zero score)
    category:b
    category:c (...and so on for every value of 'category')

These sorted sets simply hold ids to the objects that they represent collections of. You can then ask for arrays of ids for items that are in multiple sets:

    ItemListMaster.index!
    ItemListMaster.intersect 'power', 'category:category_one', limit: 10, offset: 20
    #=> Struct {
      :results => Array of ids of Items in 'category_one' ordered by 'power_level',
      :offset => integer,
      :limit => integer,
      :reverse => boolean,
      :total_entries => integer
    }
