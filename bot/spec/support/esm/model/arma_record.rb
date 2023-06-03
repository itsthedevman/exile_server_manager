# frozen_string_literal: true

module ESM
  class ArmaRecord < ActiveRecord::Base
    self.abstract_class = true

    establish_connection :arma_test
  end
end
