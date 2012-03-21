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
      options = args.extract_options!
      limit = options[:limit]
      offset = options[:offset] || 0

      args = args.map { |a| "list_master:#{redis.namespace}:#{a}" }

      redis.zinterstore "list_master:#{redis.namespace}:out", args

      if limit
        redis.zrange('out', offset, offset + limit - 1).map(&:to_i)
      else
        redis.zrange('out', offset, -1).map(&:to_i)
      end
    end
    private
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
      def update
        all_sets = redis.smembers('all_sets').select { |s| s.include?(':') }

        query = @model.send(@scope)
        @associations.each do |association|
          query = query.includes(association)
        end

        query.find_in_batches do |models|
          models.each do |model|

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

                add_to_unscored_set model, set[:name], set[:where], possible_sets
              end

            end
          end
        end
      end

    #
    # Adds the model to the given set with score equal to the value of <attribute> on model
    # If attribute_block is set, then the score used is <attribute> on the return value of the block.
    #
    def add_to_scored_set set_name, model, attribute_block, attribute, descending
      model_with_attribute = (attribute_block || lambda {|m| model}).call(model)
      return unless model_with_attribute
      score = model_with_attribute.read_attribute(attribute).to_score
      score *= -1 if descending
      redis.multi do
        redis.zadd set_name, score, model.id
        redis.sadd 'all_sets', set_name
      end
    end

    def add_to_unscored_set model, attribute_name, condition, possible_sets
      if condition
        return unless condition.call(model)
        set_name = attribute_name
      else
        set_name = attribute_name + ':' + model.read_attribute(attribute_name).to_s
      end

      # Remove from previous sets
      redis.multi do
        possible_sets.each do |set|
          redis.zrem set, model.id
        end
        redis.zadd set_name, 0, model.id
        redis.sadd 'all_sets', set_name
      end
    end
  end
end

class Object
  def to_score
    if respond_to? :to_i
      to_i
    elsif is_a? Date
      to_time.to_i
    else
      raise 'unable to convert #{self.inspect} to a zset score'
    end
  end
end
