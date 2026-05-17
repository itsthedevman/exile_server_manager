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
    end
  end
end
