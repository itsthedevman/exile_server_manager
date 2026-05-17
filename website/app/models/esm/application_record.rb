# frozen_string_literal: true

module ESM
  class ApplicationRecord < ActiveRecord::Base
    include PublicAttributes

    def dom_id
      "#{self.class.table_name.singularize}-#{public_id}"
    end

    def to_param
      public_id
    end
  end
end
