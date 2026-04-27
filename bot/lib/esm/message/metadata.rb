# frozen_string_literal: true

module ESM
  class Message
    class Metadata < OpenStruct
      def to_h
        super.tap do |hash|
          hash.delete_if { |_k, v| v.blank? }
        end
      end
    end
  end
end
