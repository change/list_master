require 'securerandom'

module ListMaster::IndexMethods

  # Public: recreate all sets by querying for models
  #
  # First, every model in this module's @scope is looked up and is zadd-ed to
  # all of its sets under the "processing" namespace. When that is finished,
  # the sets are renamed to overwrite the old sets.
  #
  # Returns nothing.
  PROCESSING_PREFIX = :processing
  def index!
    # Unique prefix for temporary sets (in case multiple calls to index!)
    prefix = "#{PROCESSING_PREFIX}:#{SecureRandom.hex}"

    new_sets = Set.new

    # Recreate all sets under temporary namespace
    query_for_models.find_each do |model|
      sets_for_model(model).each_pair do |set, score|
        new_sets << set
        redis.zadd "#{prefix}:#{set}", score, model.id
      end
    end

    # Drop in new sets for old sets
    new_sets.each { |set| redis.rename "#{prefix}:#{set}", set }

    remove_unwanted_sets! new_sets
    true
  end

  private

  def query_for_models
    @model.send(@scope).includes(@associations)
  end

  def sets_for_model(model)
    result = {}
    @sets.each do |set|
      next unless set[:if].call(model)

      if set[:attribute] # sorted sets
        model_with_attribute = set[:on].call(model)
        next unless model_with_attribute
        score = score_field model_with_attribute.send(set[:attribute])
        score *= -1 if set[:descending]
        result[set[:name]] = score
      else # unsorted sets
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
    end
    result
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

  # Remove any stragglers (in case sets are removed from the definition)
  def remove_unwanted_sets!(new_sets)
    regex = /^#{PROCESSING_PREFIX}/
    everything_without_other_processing_sets = redis.keys.reject{|k| k =~ regex }
    without_meta_keys = everything_without_other_processing_sets - %w(meta)
    without_new_sets = without_meta_keys - new_sets.to_a

    without_new_sets.each { |k| redis.del k }
  end
end
