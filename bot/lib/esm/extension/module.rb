# frozen_string_literal: true

class Module
  #
  # Similar to #attr_reader, #attr_writer, #attr_accessor, this method sets predicate (true checker) methods for the given names
  #
  # @param *attributes [String, Symbol] The name of the instance variable to create the predicate for
  #
  def attr_predicate(*attributes)
    attributes.each do |attribute|
      module_eval <<-STR, __FILE__, __LINE__ + 1
        def #{attribute}?
          !!instance_variable_get("@#{attribute}")
        end
      STR
    end

    nil
  end
end
