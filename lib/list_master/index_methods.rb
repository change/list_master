# frozen_string_literal: true

require 'securerandom'

module ListMaster
  module IndexMethods
    # Public: recreate all sets by querying for models
    #
    # First, every model in this module's @scope is looked up and is zadd-ed to
    # all of its sets under the "processing" namespace. When that is finished,
    # the sets are renamed to overwrite the old sets.
    #
    # Returns nothing.
    PROCESSING_PREFIX = :processing
    TTL = 86_400
    def index!
      # Unique prefix for temporary sets (in case multiple calls to index!)
      prefix = "#{PROCESSING_PREFIX}:#{SecureRandom.hex}"

      @new_sets = Set.new
      @temp_sets = {}

      # Recreate all sets under temporary namespace
      query_for_models.find_each do |model|
        sets_for_model(model).each_pair do |set, score|
          temp_set = "#{prefix}:#{set}"
          # add to temp sets if its not there already
          @temp_sets[temp_set] = [] if @temp_sets[temp_set].nil?
          # add entry to temp set
          @temp_sets[temp_set] << [score, model.id]

          # if temp set size if big, lets do one redis command and push them all in
          add_set_to_redis(temp_set, set, @temp_sets[temp_set]) if @temp_sets[temp_set].size > 1000
        end
      end

      # temp sets that haven't been cleared need to be cleared and added
      @temp_sets.each_pair do |temp_set, entries|
        set = temp_set.gsub("#{prefix}:", '')
        add_set_to_redis(temp_set, set, entries)
      end

      # Drop in new sets for old sets
      @new_sets.each do |set|
        temp_set = "#{prefix}:#{set}"
        redis.multi do |_multi|
          redis.persist temp_set
          redis.rename temp_set, set
        end
      end

      remove_unwanted_sets!(@new_sets) if @remove_sets
      true
    end

    private

    def add_set_to_redis(temp_set, set, entries)
      redis.zadd temp_set, entries
      @temp_sets.delete(temp_set)
      return if @new_sets.include?(set)

      @new_sets << set
      redis.expire temp_set, TTL
    end

    def query_for_models
      @model.send(@scope).includes(@associations)
    end

    def sets_for_model(model)
      result = {}
      @sets.each do |set|
        next unless set[:if].call(model)

        retry_count = 0

        begin
          if set[:attribute]
            handle_sorted_set(model, set, result)
          else # unsorted sets
            handle_unsorted_set(model, set, result)
          end
        rescue ActiveRecord::StatementInvalid, Mysql2::Error
          raise "Mysql2::Error after #{retry_count} retries" unless retry_count < 3

          ActiveRecord::Base.connection.reconnect!
          retry_count += 1
          retry
        end
      end
      result
    end

    def handle_sorted_set(model, set, result)
      model_with_attribute = set[:on].call(model)
      return unless model_with_attribute

      score = score_field(model_with_attribute.send(set[:attribute]))
      score *= -1 if set[:descending]
      result[set[:name]] = score
    end

    def handle_unsorted_set(model, set, result)
      if set[:multi]
        collection = set[:multi].call(model).compact
        set_names = collection.map { |i| set[:name] + ':' + i }
      elsif set[:single]
        set_names = [set[:name]]
      else
        set_names = [set[:name] + ':' + model.send(set[:name]).to_s]
      end
      set_names.each do |set_name|
        result[set_name] = 0
      end
    end

    def score_field(field)
      if field.respond_to? :to_i
        field.to_i
      elsif field.is_a? Date
        field.to_time.to_i
      else
        raise "unable to convert #{inspect} to a zset score"
      end
    end

    # Remove any stragglers (in case sets are removed from the definition)
    def remove_unwanted_sets!(new_sets)
      regex = /^#{PROCESSING_PREFIX}/
      everything_without_other_processing_sets = redis.keys.reject { |k| k =~ regex }
      without_meta_keys = everything_without_other_processing_sets - %w[meta]
      without_new_sets = without_meta_keys - new_sets.to_a

      without_new_sets.each { |k| redis.del k }
    end
  end
end
