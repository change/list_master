# ListMaster::Base
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

module ListMaster
  module Base

    #
    # This instance's redis namespace
    #
    def redis
      @redis ||= Redis::Namespace.new self.name.underscore, :redis => ListMaster.redis
    end


    #
    # Refreshes the redis sets
    #
    def process
      clean
      update
    end

    #
    # Takes a sequence of list names to intersect
    # Also has options :limit (default 10) and :offset (default 0)
    #
    # Returns an Array of integer ids
    #
    def intersect *args
      options     = args.extract_options!
      limit       = options[:limit]    || -1
      offset      = options[:offset]   || 0
      reverse     = options[:reverse]  || false

      # Key to store result in
      output      = 'zinterstore_out'

      # How much to return from the result
      start_index = offset
      stop_index  = limit > -1 ? start_index + limit - 1 : -1

      # Hack because Redis::Namespace#zinterstore is not implemented
      namespace              = "#{ListMaster.redis.namespace}:#{redis.namespace}"
      fully_qualified_args   = args.map { |a| "#{namespace}:#{a}" }
      fully_qualified_output = "#{namespace}:#{output}"

      results = redis.multi do
        redis.zinterstore fully_qualified_output, fully_qualified_args
        if reverse
          redis.zrevrange(output, start_index, stop_index)
        else
          redis.zrange(output, start_index, stop_index)
        end
      end

      Struct.new(:results, :offset, :limit, :reverse, :total_entries).new(
          results.last.map(&:to_i),
          offset,
          limit,
          reverse,
          results.first
        )

    end

    #
    # Finds ids that are no longer in the given scope and removes them from each set
    #
    def clean
      good_ids = @model.send(@scope).select(:id).map(&:id)

      redis.del 'good'
      good_ids.each { |i| redis.sadd 'good', i }
      # Get the diff of the wanted/unwanted id's and use it to 'clean'
      # the current sets, keeping only wanted records around
      ids_to_remove = redis.sdiff 'all', 'good'

      redis.smembers('all_sets').each do |set_name|
        ids_to_remove.each do |id|
          redis.zrem set_name, id
        end
      end
    end


    #
    # Goes through every record of the model in the given scope and adds the id to every relevant set
    #
    def update(options = {})
      options.symbolize_keys!
      all_sets = redis.smembers('all_sets').select { |s| s.include?(':') }

      query = @model.send(@scope)

      # find_each doesn't support limit
      # there was a pull request adding this -- https://github.com/rails/rails/pull/5696
      # but it was rejected as you can simulate this behavior without
      # modifying the find_each API.
      # we find low_id and high_id instead of just getting a range
      # of ids so we avoid having to select all the instances to get
      # a list of ids, and because SELECT ... IN is less performant than
      # SELECT ... BETWEEN when dealing with large ranges
      if options[:limit]
        low_id = query.order(:id).offset(options[:offset]).limit(1).select(:id).first.try(:id)
        high_id = query.order(:id).offset(options[:offset]).limit(options[:limit]).select(:id).reverse.first.try(:id)
        # if the offset is > number of elements, we'll just return an empty results set
        query = low_id ? query.where(id: low_id..high_id) : query.where(id: nil)
      end

      query = query.includes(@associations)

      query.find_each do |model|
        redis.sadd 'all', model.id

        # For every declared set, set add this model's id
        @sets.each do |set|

          # SCORED SETS
          if set[:attribute]
            # When :on is set a model will be finding the attribute that is set
            # 'on' the model specified. This can be a name or a lambda that will
            # return the selected values

            add_to_scored_set set[:name], model, set[:on], set[:attribute], set[:descending]

          # NON-SCORED SETS
          else
            possible_sets = all_sets.select { |s| s.match(/^#{set[:name]}:/) }

            add_to_unscored_set model, set[:name], set[:where], set[:multi], possible_sets
          end

        end
      end
    end


    private
    #
    # Adds the model to the given set with score equal to the value of <attribute> on model
    # If attribute_block is set, then the score used is <attribute> on the return value of the block.
    #
    def add_to_scored_set set_name, model, attribute_block, attribute, descending
      model_with_attribute = attribute_block.call(model)
      return unless model_with_attribute
      score = score_field model_with_attribute.send(attribute)
      score *= -1 if descending
      redis.multi do
        redis.zadd set_name, score, model.id
        redis.sadd 'all_sets', set_name
      end
    end

    def score_field field
      if field.respond_to? :to_i
        field.to_i
      elsif field.is_a? Date
        field.to_time.to_i
      else
        raise 'unable to convert #{self.inspect} to a zset score'
      end
    end

    def add_to_unscored_set model, attribute_name, condition, multi, possible_sets
      if multi
        collection = multi.call(model).compact
        set_names = collection.map { |i| attribute_name + ':' + i }
      elsif condition
        return unless condition.call(model)
        set_names = [attribute_name]
      else
        set_names = [attribute_name + ':' + model.send(attribute_name).to_s]
      end

      # Remove from previous sets
      redis.multi do
        possible_sets.each do |set|
          redis.zrem set, model.id
        end
        set_names.each do |set|
          redis.zadd set, 0, model.id
          redis.sadd 'all_sets', set
        end
      end
    end
  end
end
