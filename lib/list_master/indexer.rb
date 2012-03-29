module ListMaster::Indexer

  ##
  # Refreshes the redis sets
  ##
  def index_list_master!
    clean
    update
  end

  private

  ##
  # Finds ids that are no longer in the given scope and removes them from each set
  ##s
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


  ##
  # Goes through every record of the model in the given scope and adds the id to every relevant set
  ##
  def update
    all_sets = redis.smembers('all_sets').select { |s| s.include?(':') }

    query = @model.send(@scope)
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

  ##
  # Adds the model to the given set with score equal to the value of <attribute> on model
  # If attribute_block is set, then the score used is <attribute> on the return value of the block.
  ##
  def add_to_scored_set set_name, model, attribute_block, attribute, descending
    model_with_attribute = attribute_block.call(model)
    return unless model_with_attribute
    score = score_field model_with_attribute.read_attribute(attribute)
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
      collection = model.send(attribute_name)
      set_names = collection.map { |i| attribute_name + ':' + multi.call(i) }
    elsif condition
      return unless condition.call(model)
      set_names = [attribute_name]
    else
      set_names = [attribute_name + ':' + model.read_attribute(attribute_name).to_s]
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
