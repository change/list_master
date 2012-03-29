module ListMaster::Definition

  ##
  # Use a mini DSL to define the sequences and filters for
  # this subclass of ActiveRecord::Base. For example,
  #
  #   class Person < ActiveRecord::Base
  #     define_list_master do
  #       sequences { date_of_birth }
  #       filter    { first_letter_of_last_name attribute: { |p| p.last_name[0] } }
  #     end
  #   end
  #
  # One sequence is combined with zero or more filters as follows:
  #
  #   Person.intersect :date_of_birth, first_letter_of_last_name: 'P'
  ##
  def list_master &block
    if block_given?
      dsl = Dsl.new(self)
      dsl.instance_eval(&block)
      debugger;1
      self.class_variable_set(:@@list_master, dsl.to_hash.merge(redis: Redis::Namespace.new(self.name.underscore, redis: ListMaster.redis)))
    else
      self.class_variable_get(:@@list_master)
    end
  end

  class Dsl

    def initialize(klass)
      @sequences    = {}
      @filters      = {}
      @scoping      = []
      @associations = []
    end

    ##
    # Define orderings of records to index.
    #
    # Example:
    #
    #   sequences {
    #     created_at
    #     # => a sequence of records ordered by created_at
    #
    #     oldest, attribute: :created_at
    #     # => a sequence of records ordered by created_at
    #
    #     recent, attribute: :created_at, descending: true
    #     # => a sequence of records ordered by created_at DESC
    #
    #     rank, attribute: lambda { |r| r.profile.rank }
    #     # => a sequence of records ordered by the rank attribute of the associated profile
    #   }
    ##
    def sequences &block
      @sequences.merge! MethodHashProxy.new.instance_eval(&block)
    end

    def filters &block
      @filters.merge! MethodHashProxy.new.instance_eval(&block)
    end

    ##
    # Specify a scope to restrict the redis sets to.
    # Defaults to unscoped.
    ##
    def scope scope_name
      @scoping << scope_name.to_sym
    end


    ##
    # Specify an association to be included when indexing.
    # This is useful if indexing requires an attribute on
    # an associated item. This will allow the associatied items
    # to be queried in batches during indexing.
    ##
    def associated *associations
      associations.each { |a| @associations << a }
    end

    ##
    # A Hash with the resulting ListMaster configuration
    ##
    def to_hash
      {
        sequences:        @sequences,
        filters:          @filters,
        scoping:  @scoping,
        associations:     @associations
      }
    end

    ##
    # A subclass of BasicObject that records every method call
    # in a Hash, where the key is the name of the method and the
    # value is a Hash containing the value of args.extract_options!
    ##
    class MethodHashProxy < BasicObject
      attr_reader :method_calls
      include ::Kernel

      def initialize
        @method_calls = {}
      end

      private

      def method_missing(method, *args, &block)
        @method_calls.merge! method => args.extract_options!
      end
    end

  end
end
