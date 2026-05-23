# frozen_string_literal: true

module ESM
  class IpcClient
    ##
    # Raised when the transport itself can't reach the bot: no broker, request
    # timeout, connection refused, or no subscriber for the subject. Callers
    # typically map this to a user-facing "service unavailable" state.
    #
    class Unreachable < StandardError; end
  end
end
