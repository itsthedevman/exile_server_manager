# frozen_string_literal: true

module Mocks
  class AttrPredicateMock
    attr_accessor :one, :two
    attr_reader :three

    attr_predicate :one, :two, :three

    def initialize
      @three = 3
    end
  end
end
