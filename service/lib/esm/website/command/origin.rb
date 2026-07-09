# frozen_string_literal: true

module ESM
  module Website
    module Command
      class Origin < ESM::Command::Origin
        def initialize(server_command)
          @server_command = server_command
        end

        def current_user
          @server_command.user
        end

        def reply(content)
          raise ArgumentError, "You can only reply to this origin once" if @server_command.settled?

          @server_command.update!(status: :completed, result: content)
        end

        def log_context
          {
            server_command: @server_command.attributes
          }
        end

        # The website doesn't execute from within a community
        def current_community = nil

        # The website doesn't execute from within a channel
        def current_channel = nil
      end
    end
  end
end
