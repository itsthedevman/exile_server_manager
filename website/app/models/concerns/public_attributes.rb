# frozen_string_literal: true

module PublicAttributes
  extend ActiveSupport::Concern

  included do
    class_attribute :public_attributes_list, default: []
  end

  class_methods do
    def public_attributes(*attributes)
      self.public_attributes_list = attributes
    end
  end

  def public_attributes
    result = {}

    public_attributes_list.each do |attr|
      case attr
      when Symbol
        result[attr] = public_send(attr)
      when Hash
        attr.each do |key, proc|
          result[key] = proc.call(self)
        end
      end
    end

    result.with_indifferent_access
  end
end
