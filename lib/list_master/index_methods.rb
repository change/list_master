require 'securerandom'
require 'tempfile'

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
    prefix = "#{PROCESSING_PREFIX}:#{SecureRandom.hex}"
    temp_files ||= Hash.new do |h, k|
      temp = Tempfile.new(k)
      temp.sync = true
      temp.write "**\r\n"
      temp.write redis_arg('ZADD')
      temp.write redis_arg(unqualified_key(k, prefix))
      h[k] = temp
    end

    # Recreate all sets in temp files
    query_for_models.find_each do |model|
      sets_for_model(model).each_pair do |set, score|
        temp_files[set].write redis_arg(score)
        temp_files[set].write redis_arg(model.id)
      end
    end

    # Insert new sets into temporary sets in redis
    temp_files.values.each do |temp_file|
      pipe_file_to_redis(temp_file.path)
    end

    # Swap out new sets for old sets
    temp_files.keys.each do |set|
      redis.rename "#{prefix}:#{set}", set
    end

    # Remove any sets that should be deleted
    remove_unwanted_sets! temp_files.keys

    true
  ensure
    temp_files.values.each { |t| t.close; t.unlink }
  end

  private

  # raw representation of a redis argument
  # see: http://redis.io/topics/mass-insert
  def redis_arg(arg)
    "$#{arg.to_s.bytesize}\r\n#{arg}\r\n"
  end

  def unqualified_key(key, prefix)
    namespaces = []
    redis = self.redis
    while redis.is_a? Redis::Namespace
      namespaces.unshift(redis.namespace)
      redis = redis.redis
    end
    namespaces << prefix
    "#{namespaces.join(':')}:#{key}"
  end

  def pipe_file_to_redis(file_path)
    # We insert the number of redis arguments into the first line
    num_lines = `wc -l #{file_path}`.split.first.to_i
    num_args = ((num_lines - 1) / 2).to_i
    `sed -e 's/^\\*\\*/*#{num_args}/' -i .bak #{file_path}`

    `redis-cli -h #{redis.client.host} -p #{redis.client.port} -n #{redis.client.db} --pipe < #{file_path}`
  end

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
