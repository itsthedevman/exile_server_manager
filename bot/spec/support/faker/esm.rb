# frozen_string_literal: true

module Faker
  class ESM
    class << self
      def server_id(community_id: self.community_id)
        "#{community_id}_#{Faker::Alphanumeric.alphanumeric(number: Faker::Number.between(from: 1, to: 32))}"
      end

      def community_id
        Faker::Alphanumeric.alphanumeric(number: Faker::Number.between(from: 1, to: 32)).to_s
      end

      # Steam UIDs (Steam64) are 17 digits and always start with the
      # universe+account-type prefix 7656119 for individual accounts.
      def steam_uid
        "7656119#{Faker::Number.number(digits: 10)}"
      end
    end
  end
end
