# frozen_string_literal: true

# rubocop:disable Style/TrivialAccessors
module ListMaster
  class Dsl
    def initialize
      @scope = :unscoped
      @sets = []
      @associations = []
      @remove_sets = true
    end

    def namespace(namespace)
      @namespace = namespace
    end

    def remove_sets(remove)
      @remove_sets = remove
    end

    #
    # Associating this list master with a model
    #
    def model(model_class)
      @model = model_class
    end

    #
    # Specify a scope to query for when updating redis sets
    #
    def scope(scope_name)
      @scope = scope_name
    end

    #
    # Add an association to include as part of the process query
    #
    def associated(association)
      @associations << association
    end

    #
    # Defining sets to maintain
    #
    def set(*args)
      options = args.extract_options!
      @sets << {
        name: args.first.to_s,
        attribute: nil,
        descending: nil,
        on: ->(m) { m },
        if: ->(_m) { true },
        multi: nil,
        single: false,
      }.merge(options)
    end
  end
end
# rubocop:enable Style/TrivialAccessors
