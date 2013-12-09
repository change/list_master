module ListMaster
  class Dsl

    def initialize
      @scope = :unscoped
      @sets = []
      @associations = []
    end

    def namespace namespace
      @namespace = namespace
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
    # Add an association to include as part of the process query
    #
    def associated association
      @associations << association
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
        on: lambda {|m| m},
        if: lambda {|m| true},
        multi: nil,
        single: false,
      }.merge(options)
    end

  end
end
