# frozen_string_literal: true

module ESM
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
