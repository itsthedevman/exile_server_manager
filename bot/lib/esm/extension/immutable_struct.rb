# frozen_string_literal: true

class ImmutableStruct < Data
  def self.name
    "ImmutableStruct"
  end

  alias_method :to_hash, :to_h
  alias_method :values, :deconstruct

  # Act like ostruct and return nil if the method isn't defined
  def method_missing(method_name, *, &)
    send(method_name, *, &) if self.class.method_defined?(method_name)
  end

  def respond_to_missing?(_method_name, _include_private = false)
    true
  end
end
