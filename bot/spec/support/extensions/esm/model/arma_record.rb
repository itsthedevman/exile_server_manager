# frozen_string_literal: true

module ESM
  class ArmaRecord < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
    self.abstract_class = true

    establish_connection :arma_test
  end
end
