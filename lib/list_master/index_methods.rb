module ListMaster::IndexMethods

  # Public: recreate all sets by querying for models
  #
  # First, every model in this module's @scope is looked up and is zadd-ed to
  # all of its sets under the "processing" namespace. When that is finished,
  # the sets are renamed to overwrite the old sets.
  #
  # Returns nothing.
  def index!
    # Recreate all sets under 'processing' namespace
    query_for_models.find_each do |model|
      sets_for_model(model).each_pair do |set, score|
        redis.zadd "processing:#{set}", score, model.id
      end
    end

    # Get "new" names of all sets just processed
    new_sets = redis.keys.map { |k| /^processing:(.*)/.match(k) { |m| m[1] } }.compact

    # Drop in new sets for old sets
    new_sets.each { |set| redis.rename "processing:#{set}", set }

    # Remove any stragglers (in case sets are removed from the definition)
    (redis.keys - %w(meta) - new_sets).each { |k| redis.del k }
  end

  private

  def query_for_models
    @model.send(@scope).includes(@associations)
  end

  def sets_for_model(model)
    result = {}
    @sets.each do |set|
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
end
