module ListMaster::IntersectMethods

  # Public: intersect a list of sets and output a range and ids
  #
  # *args - set names to intersect
  # options - A Hash containing the options :limit (default none) and :offset (default 0)
  #
  # Returns an Array of integer ids
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

end
