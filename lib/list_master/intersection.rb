# ListMaster::Intersection
#
# This is a base class for an object that maintains redis zsets for an ActiveRecord model.
# A list of sets are defined in a mini DSL.
#
# For example, let's say you have a model Item with attributes 'power_level and 'category'.
# You would define the ListMaster for this as follows:
#
# class ItemListMaster < ListMaster::Base
#   model 'Item'
#
#   set 'power', :attribute => 'power_level'
#   set 'category'
# end
#
# Now when ItemListMaster.new.process is called, the following sorted sets will be put in redis:
#
#   power                   (items scored by there 'power_level' attribute)
#   category:category_one   (all items have zero score)
#   category:category_two
#   category:category_three (...and so on for every value of 'category')
#
# These sorted sets simply hold ids to the objects that they represent collections of.
#
# You can then ask for arrays of ids for items that are in multiple sets:
#
# a = ItemListMaster.new
# a.process
# a.intersect 'power', 'category:category_one' #=> Array of ids of Items in 'category_one' ordered by 'power_level'

module ListMaster::Intersection

  def intersect *args
    ids = self::ListMaster.intersect(*args)
    self.order("field(id, #{ids.join(',')})").where(id: ids)
  end

  def intersect_ids
    options     = args.extract_options!
    limit       = options[:limit]  || -1
    offset      = options[:offset] || 0

    # Key to store result in
    output      = 'zinterstore_out'

    # How much to return from the result
    start_index = offset
    stop_index  = limit > -1 ? start_index + limit - 1 : -1

    # Hack because Redis::Namespace#zinterstore is not implemented
    namespace              = "#{ListMaster.redis.namespace}:#{redis.namespace}"
    fully_qualified_args   = args.map { |a| "#{namespace}:#{a}" }
    fully_qualified_output = "#{namespace}:#{output}"

    redis.multi do
      redis.zinterstore fully_qualified_output, fully_qualified_args
      redis.zrange(output, start_index, stop_index)
    end.last.map(&:to_i)
  end

end
