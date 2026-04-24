# frozen_string_literal: true

module ESM
  module Website
    #
    # Inbound IPC surface for the website. Boots a single `Server`
    # instance, registers every RPC handler, and exposes lifecycle hooks
    # that mirror the existing `ESM::API.run` / `ESM::API.stop` contract.
    #
    module API
      class << self
        # @return [Server, nil] the running server instance
        attr_reader :server

        def run
          @server = Server.new
            .register("ping", Handlers::Ping.new)
            .start
        end

        def stop
          @server&.stop
          @server = nil
        end
      end
    end
  end
end
