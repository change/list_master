# frozen_string_literal: true

module ListMaster
  module IntersectMethods
    # Public: intersect a list of sets and output a range and ids
    #
    # *args - set names to intersect
    # options - A Hash containing the options :limit (default none) and :offset (default 0)
    #
    # Returns an Array of integer ids
    def intersect(*args)
      options     = args.extract_options!
      limit       = options[:limit]    || -1
      offset      = options[:offset]   || 0
      reverse     = options[:reverse]  || false

      # Key to store result in
      output = 'zinterstore_out'

      # How much to return from the result
      start_index = offset
      stop_index  = limit > -1 ? start_index + limit - 1 : -1

      results = redis.multi do |pipeline|
        pipeline.zinterstore(output, args)
        if reverse
          pipeline.zrevrange(output, start_index, stop_index)
        else
          pipeline.zrange(output, start_index, stop_index)
        end
      end

      Struct.new(:results, :offset, :limit, :reverse, :total_entries).new(
        results.last.map(&:to_i),
        offset,
        limit,
        reverse,
        results.first,
      )
    end
  end
end
