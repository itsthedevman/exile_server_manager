# frozen_string_literal: true

# Overseer watches and checks pending requests to servers for timeouts
module ESM
  class Websocket
    class Request
      class Overseer
        # Starts a thread that loops over all connections requests and times them out if they are taking too long
        # @private
        def self.start!
          @thread = Thread.new do
            loop do
              check_connections
              sleep(ESM.env.test? ? 0.5 : 30)
            end
          end
        end

        # Stops the EM thread
        def self.die
          return if @thread.nil?

          Thread.kill(@thread)
        end

        # Checks all the connections
        # @private
        def self.check_connections
          ESM::Websocket.connections.each(&method(:process_connection))
        end

        # Checks a connection's requests
        # @private
        def self.process_connection(_server_id, connection)
          @connection = connection
          @connection.requests.each(&method(:check_request))
        end

        # Finally, check a single request, and remove it if it's timed out
        # @private
        def self.check_request(id, request)
          return if !request.timed_out?

          # Remove the request
          @connection.remove_request(id)

          # Don't warn on our internal messages
          return if request.user.nil?

          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t(
                "request_timed_out",
                command_message: request.command.event.message.content,
                server_id: @connection.server.server_id,
                user: request.user.mention
              )

              e.color = :red
            end

          # Let the user know
          request.command.reply(embed)
        rescue StandardError => e
          ESM.logger.error("overseer#check_request") { e.message }
        end
      end
    end
  end
end
