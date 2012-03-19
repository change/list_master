module ListMaster
  class Dsl

    def initialize
      @scope = :unscoped
      @sets = []
    end

    #
    # Associating this list master with a model
    #
    def model model_class
      @model = model_class
    end


    #
    # Specify a scope to query for when updating redis sets
    #
    def scope scope_name
      @scope = scope_name
    end


    #
    # Defining sets to maintain
    #
    def set *args
      options = args.extract_options!
      @sets << {
        name: args.first.to_s,
        attribute: nil,
        descending: nil,
        on: nil,
        where: nil
      }.merge(options)
    end

  end
end
