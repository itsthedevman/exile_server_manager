# frozen_string_literal: true

module ESM
  module Arma
    class Client
      # Registers a pending promise in the ledger for the given id WITHOUT sending
      # anything over the socket. Specs use this to wait on a response they trigger
      # directly via execute_sqf! (rather than by sending a real request).
      def register_response(id)
        @ledger.add(Request.new(id:, type: :message, content: nil))
      end
    end
  end
end
