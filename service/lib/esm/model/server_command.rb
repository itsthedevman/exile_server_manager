# frozen_string_literal: true

module ESM
  class ServerCommand < ApplicationRecord
    #
    # Runs the given work off the calling thread and records the outcome on the row,
    # letting the dispatcher ack receipt without waiting for the Arma round-trip.
    #
    # The row moves to :dispatched before the work runs, then to :completed on
    # success, :timed_out when the work raises RequestTimeout, or :failed on any
    # other error. An ExtensionError is a business rejection (e.g. not enough
    # poptabs), so its player-facing text is recorded for the website to show; an
    # unexpected error is logged and left without a user-facing message.
    #
    # @yield runs the command's work; its return value is unused.
    #
    # @return [self] returned before the work finishes, so the caller can ack.
    #
    def execute(&block)
      Concurrent::Promise.execute do
        ESM::Database.with_connection do
          update!(status: :dispatched)

          yield

          update!(status: :completed)
        rescue ESM::Exception::RequestTimeout
          update!(status: :timed_out)
        rescue ESM::Exception::ExtensionError => e
          update!(status: :failed, error_message: e.data.join("\n"))
        rescue => e
          ESM.logger.error!(error: e)
          update!(status: :failed)
        end
      end

      self
    end
  end
end
