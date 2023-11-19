# frozen_string_literal: true

module ESM
  class Websocket
    class Request
      attr_reader :id, :user, :command, :channel, :remove_on_ignore
      attr_reader :command_name, :user_info if ESM.env.test?
      attr_accessor :response

      # command: nil, user: nil, channel: nil, parameters: nil, timeout: 30, command_name: nil
      def initialize(**args)
        @command = args[:command]
        @user = args[:user]

        # String for direct calls, Otherwise its a command
        @command_name =
          (args[:command_name].presence || @command.name)

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
        @created_at = ::Time.zone.now

        # This controls if the request should be removed on the first reply back from Arma.
        @remove_on_ignore = args[:remove_on_ignore] || false
      end

      # The DLL requires it to be this format
      def to_h
        {
          "command" => @command_name,
          "commandID" => @id,
          "authorInfo" => @user_info,
          "parameters" => @parameters
        }
      end

      def to_s
        to_h.to_json
      end

      def timed_out?
        (::Time.zone.now - @created_at) >= @timeout
      end

      def on_reply=(callback)
        @on_reply_callback = callback
      end

      def on_reply(connection)
        @on_reply_callback.call(connection) if defined?(@on_reply_callback)
      end
    end
  end
end
