# frozen_string_literal: true

#
# A base class that allows for creating classes that can be asked questions.
# Very similar to ActiveSupport::StringInquirer and ArrayInquirer, except stricter
# See initializer
#
class Inquirer
  #
  # @param *predicates [Array<String>, Array<Symbol>] The questions this class can be asked
  #
  # @example Implementing StringInquirer
  #   environment = Inquirer.new(:production, :staging, :test, :development)
  #   environment.set(ENV["RAILS_ENV"] || :development)
  #
  #   environment.staging? #=> false
  #   environment.development? #=> true
  #   environment.predicate_does_not_exist? #=> undefined method predicate_does_not_exists? for Inquirer
  #
  # @example Implementing ArrayInquirer
  #   fruits = Inquirer.new(:apples, :oranges, :bananas, default: [:oranges, :bananas])
  #
  #   fruits.apples? #=> false
  #   fruits.oranges? #=> true
  #   fruits.bananas? #=> true
  #   fruits.grapes? #=> undefined method grapes? for Inquirer
  def initialize(*predicates, default: nil)
    @predicates = predicates.map(&:to_sym)
    self.class.attr_predicate(*@predicates)

    if default
      default = [default] unless default.is_a?(Array)
      set(*default)
    end
  end

  #
  # Sets the provided predicates to true
  #
  # @param *predicates [Array<Symbol>] Which predicates to set to true
  # @param unset [TrueClass, FalseClass, Array, Symbol] Which predicates to unset
  #     FalseClass: Do nothing.
  #     TrueClass: Un-sets all other predicates. Default
  #     Array: Un-set the provided predicates
  #     Symbol: Un-set the provided predicate
  #
  # @return [Self]
  #
  def set(*predicates, unset: true)
    predicates = predicates.map(&:to_sym)

    if (invalid_predicates = predicates - @predicates) && invalid_predicates.size > 0
      raise ArgumentError, "#{invalid_predicates} are not allowed as predicates for #{self.class.name}. Valid options: #{@predicates}"
    end

    # Unset
    case unset
    when true
      unset(*@predicates)
    when Array, Symbol
      unset = [unset] unless unset.is_a?(Array)
      unset(*unset)
    end

    # Set
    predicates.each do |predicate|
      instance_variable_set(:"@#{predicate}", true)
    end

    self
  end

  #
  # Sets the provided predicates to false
  #
  # @param *predicates [Array<Symbol>] Which predicates to set to false
  #
  # @return [Self]
  #
  def unset(*predicates)
    predicates.map(&:to_sym).each do |predicate|
      next if @predicates.exclude?(predicate)

      instance_variable_set(:"@#{predicate}", false)
    end

    self
  end

  def to_h
    @predicates.index_with do |predicate|
      instance_variable_get(:"@#{predicate}")
    end
  end

  def to_a
    to_h.select { |_predicate, enabled| enabled }.keys
  end

  def to_s
    enabled_predicates = to_a

    if enabled_predicates.size > 1
      enabled_predicates.to_s
    else
      enabled_predicates.first.to_s
    end
  end

  alias_method :inspect, :to_s

  # This calls `#to_sym` on the return of `#to_s`
  delegate :to_sym, to: :to_s
end
