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
  class Base

    class << self
      #
      # Associating this list master with a model
      #
      def model model_class
        @@model = model_class
      end

      #
      # Defining sets to maintain
      #
      @@sets = []
      def set *args
        options = args.extract_options!
        @@sets << {
          name: args.first.to_s,
          attribute: nil,
          descending: nil,
          on: nil,
          where: nil
        }.merge(options)
      end

    end

    #
    # This instance's redis namespace
    #
    def redis
      @redis ||= Redis::Namespace.new self.class.name.underscore, :redis => ListMaster.redis
    end

    #
    # Goes through every record of the model and adds the id to every relevant set
    #
    def process
      @@model.find_in_batches do |models|
        models.each do |model|
          @@sets.each do |set|
            # SCORED SETS
            if set[:attribute]
              if set[:on]
                if set[:on].is_a? Proc
                  model_with_attribute = set[:on].call(model)
                else
                  model_with_attribute = model.send(set[:on])
                end
              else
                model_with_attribute = model
              end
              next unless model_with_attribute
              score = model_with_attribute.read_attribute(set[:attribute]).to_score
              set_name = set[:name]
            # NON-SCORED SETS
            else
              score = 0
              if set[:where]
                set_name = set[:name]
                next unless set[:where].call(model)
              else
                set_name = set[:name] + ':' + model.read_attribute(set[:name]).to_s
              end
            end
            score *= -1 if set[:descending]

            redis.zadd set_name, score, model.id
          end
        end
      end
    end


    #
    # Takes a sequence of list names to intersect
    # Also has options :limit (default 10) and :offset (default 0)
    #
    # Returns an Array of integer ids
    #
    def intersect *args
      options = args.extract_options!
      limit = options[:limit] || 10
      offset = options[:offset] || 0

      args = args.map { |a| "list_master:#{redis.namespace}:#{a}" }

      redis.zinterstore "list_master:#{redis.namespace}:out", args if args.count > 1

      redis.zrange('out', offset, offset + limit).map(&:to_i)
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
