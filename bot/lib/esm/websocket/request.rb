# frozen_string_literal: true

require "esm/websocket/request/overseer"

module ESM
  class Websocket
    class Request
      attr_reader :id, :user, :command, :channel
      attr_reader :command_name, :user_info if ESM.env.test?

      # command: nil, user: nil, channel: nil, parameters: nil, timeout: 30, command_name: nil
      def initialize(**args)
        @command = args[:command]
        @user = args[:user]

        # String for direct calls, Otherwise its a command
        @command_name =
          if args[:command_name].present?
            args[:command_name]
          else
            @command.name
          end

        @user_info =
          if @user.nil?
            ["", ""]
          else
            [@user.mention, @user.id]
          end

        @channel = args[:channel]
        @parameters = args[:parameters]
        @id = SecureRandom.uuid
        @timeout = args[:timeout] || 30
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
