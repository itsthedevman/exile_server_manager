# frozen_string_literal: true

module Faker
  class Steam
    class << self
      # Steam64 IDs are 17 digits and always start with the universe + account-type
      # prefix 7656119 for individual accounts.
      def uid
        "7656119#{Faker::Number.number(digits: 10)}"
      end
    end
  end
end
