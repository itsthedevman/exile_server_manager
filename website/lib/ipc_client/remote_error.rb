# frozen_string_literal: true

class IpcClient
  ##
  # Raised when the bot responded with `ok: false`. Carries the structured
  # error type the bot chose alongside the detail string, so callers can
  # switch on `error_type` rather than parsing the message.
  #
  class RemoteError < StandardError
    # @return [Symbol] wire-level error code from the bot
    attr_reader :error_type

    ##
    # @param error_type [Symbol, String] wire-level error code; coerced to Symbol
    # @param detail [String] human-readable detail; becomes the exception message
    #
    def initialize(error_type, detail)
      @error_type = error_type.to_s.to_sym
      super(detail.to_s)
    end
  end
end
