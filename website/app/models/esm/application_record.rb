# frozen_string_literal: true

module ESM
  class ApplicationRecord < ActiveRecord::Base
    include PublicAttributes
  end
end
