# frozen_string_literal: true

# Exile's construction and container tables define a table name of "class"
# This allows writing to that value through :class_name instead
module ClassColumnSupport
  extend ActiveSupport::Concern

  class_methods do
    def instance_method_already_implemented?(method_name)
      method_name == "class" || super
    end
  end

  included do
    alias_attribute :class_name, :class
  end
end
