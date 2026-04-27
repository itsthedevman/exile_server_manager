# frozen_string_literal: true

module ESM
  module Connection
    class Response
      include Concurrent::Concern::Obligation

      #
      # Creates a new fulfilled response with the provided data
      #
      # @param content [Object] The data to set as the value for the response
      #
      # @return [self] The fulfilled response
      #
      def self.fulfilled(content)
        response = new
        response.send(:set_state, true, content, nil)
        response
      end

      #
      # Creates a new rejected response with the provided reason
      #
      # @param reason [Object] The reason why the request failed
      #
      # @return [self] The fulfilled response
      #
      def self.rejected(reason)
        response = new
        response.send(:set_state, false, nil, reason)
        response
      end

      private

      # Required by Obligation because it implements Deref
      def synchronize(&block)
        yield
      end
    end
  end
end
