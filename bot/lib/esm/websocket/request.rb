# frozen_string_literal: true

module ESM
  class Websocket
    class Request
      attr_reader :id, :user, :command, :channel
      attr_reader :command_name, :user_info if ESM.env.test?

      def initialize(command:, user:, channel:, parameters:, timeout: 30)
        @command = command
        @user = user

        # String for direct calls, Otherwise its a command
        @command_name =
          if @command.is_a?(ESM::Command::Base)
            @command.name
          else
            @command
          end

        @user_info =
          if @user.nil?
            ["", ""]
          else
            [@user.mention, @user.id]
          end

        @channel = channel
        @parameters = parameters
        @id = SecureRandom.uuid
        @timeout = timeout
        @created_at = ::Time.now
      end

      def to_s
        # The DLL requires it to be this format
        {
          "command" => @command_name,
          "commandID" => @id,
          "authorInfo" => @user_info,
          "parameters" => @parameters
        }.to_json
      end

      def timed_out?
        (::Time.now - @created_at) >= @timeout
      end
    end
  end
end
