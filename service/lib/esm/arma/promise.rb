# frozen_string_literal: true

module ESM
  module Arma
    #
    # A pending response to a request sent over the wire. Registered in the {Ledger}
    # under the request's id; the read loop calls {#set_response} when the matching
    # response arrives. Callers either block on {#wait_for_response} or attach a
    # non-blocking callback with {#on_response}.
    #
    # Backed by a single +Concurrent::IVar+, which natively models the
    # fulfilled-or-rejected obligation (value/reason/fulfilled?/rejected?) that
    # callers inspect, supports a blocking +#value+ with timeout, and notifies
    # observers on resolution.
    #
    class Promise
      def initialize
        @ivar = Concurrent::IVar.new
        @timeout_task = nil
      end

      #
      # Resolves the pending response. Called by the read loop when the matching
      # response arrives. A StandardError rejects the obligation; anything else is
      # treated as a Request and fulfills it with the request's content.
      #
      # @param response [ESM::Arma::Request, StandardError] the inbound response
      #
      # @return [Boolean] false if the obligation was already resolved (a late
      #   response after a timeout), true otherwise
      #
      def set_response(response)
        if response.is_a?(StandardError)
          @ivar.fail(response)
        else
          @ivar.set(response.content)
        end

        true
      rescue Concurrent::MultipleAssignmentError
        # Already resolved (e.g. timed out a hair before the response landed).
        # Drop the late response rather than crash the read loop.
        false
      end

      #
      # Blocks the calling thread until the response resolves or the timeout
      # elapses, then returns the obligation.
      #
      # @param timeout [Numeric, nil] seconds to wait; nil waits indefinitely
      #
      # @return [Concurrent::IVar] the resolved obligation. Responds to
      #   #fulfilled?/#rejected?/#value/#reason. A timeout is surfaced as a
      #   rejection with ESM::Exception::RequestTimeout.
      #
      def wait_for_response(timeout = nil)
        @ivar.wait(timeout)
        reject_as_timeout unless @ivar.complete?
        @ivar
      end

      #
      # Registers a non-blocking callback fired with the resolved obligation when
      # the response arrives (or the timeout elapses). The calling thread is not
      # held.
      #
      # @param timeout [Numeric] seconds before the obligation is rejected as timed out
      #
      # @return [self]
      #
      def on_response(timeout, &block)
        @timeout_task = Concurrent::ScheduledTask.execute(timeout) { reject_as_timeout }

        @ivar.add_observer do |_time, _value, _reason|
          @timeout_task&.cancel
          block.call(@ivar)
        end

        self
      end

      private

      def reject_as_timeout
        @ivar.fail(ESM::Exception::RequestTimeout.new)
      rescue Concurrent::MultipleAssignmentError
        # A real response won the race; keep its result.
        nil
      end
    end
  end
end
