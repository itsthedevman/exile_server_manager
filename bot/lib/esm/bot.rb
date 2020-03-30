# frozen_string_literal: true

module ESM
  class Bot < Discordrb::Commands::CommandBot
    attr_reader :config, :prefix

    def initialize
      # Connect to the database
      ESM::Database.connect!

      load_community_prefixes

      super(token: ESM.config.token, prefix: method(:determine_activation_prefix), help_command: false)
    end

    def run
      # Binds the Discord Events
      bind_events!

      # Register all of ESM's commands
      ESM::Command.load_commands

      # Call Discordrb::Commands::Commandbot.run
      super
    end

    ###########################
    # Discord Events!
    # These all have to have unique-to-ESM names since we are inheriting
    ###########################
    def bind_events!
      self.disconnected(&method(:esm_disconnected))
      self.mention(&method(:esm_mention))
      self.ready(&method(:esm_ready))
      self.server_create(&method(:esm_server_create))
      self.user_ban(&method(:esm_user_ban))
      self.user_unban(&method(:esm_user_unban))
    end

    def esm_disconnected(_event)
      # This event is raised when the bot has disconnected from the WebSocket, due to the Bot#stop method or external causes.
      # IDEA: Maybe send email?
      ESM::Request::Overseer.die
      ESM::Websocket::Overseer.die
    end

    def esm_mention(_event)
      # This event is raised when the bot is mentioned in a message.
    end

    def esm_ready(_event)
      # Wait until the bot has connected before starting the websocket.
      # This is to avoid servers connecting before the bot is ready
      ESM::Websocket.start!
      ESM::Request::Overseer.watch

      puts "Exile Server Manager has started\nInvite URL: #{self.invite_url}"
      @ready = true
    end

    def esm_server_create(event)
      # This event is raised when a server is created respective to the bot
      ESM::Event::ServerCreate.new(event).run!
    end

    def esm_user_ban(event)
      # This event is raised when a user is banned from a server.
      # IDEA: Ask the banning admin if they would also like to ban the user on the server
    end

    def esm_user_unban(event)
      # This event is raised when a user is unbanned from a server.
    end

    ###########################
    # Public Methods
    ###########################
    def ready?
      @ready == true
    end

    def deliver(message, to:)
      return if message.blank?

      delivery_channel = determine_delivery_channel(to)

      raise ESM::Exception::ChannelNotFound.new(message, to) if delivery_channel.nil?

      # Format the message if it's an array
      message = message.join("\n") if message.is_a?(Array)

      ESM.logger.info("#{self.class}##{__method__}") { message.to_s }

      # So we can test if it's working
      return ESM::Test.messages << [delivery_channel, message] if ESM.env.test?

      # Send the embed
      return delivery_channel.send_embed { |embed| message.transfer(embed) } if message.is_a?(ESM::Embed)

      # Send the text message
      delivery_channel.send_message(message)
    end

    def deliver_and_await!(message, user:, expected:, send_to_channel: nil, invalid_response: nil, timeout: nil, give_up_after: 99)
      counter = 0
      match = nil
      invalid_response = format_invalid_response(expected) if invalid_response.nil?
      user = determine_delivery_channel(user)

      while match.nil? && counter < give_up_after
        if send_to_channel.nil?
          deliver(message, to: user)
        else
          deliver(message, to: send_to_channel)
        end

        response =
          if ESM.env.test?
            ESM::Test.await
          else
            # Add the await event
            user.await!(timeout: timeout)
          end

        # We timed out, return nil
        return nil if response.nil?

        # Parse the match from the event
        match = response.message.content.match(Regexp.new("(#{expected.join("|")})", Regexp::IGNORECASE))

        # We found what we were looking for
        break if !match.nil?

        # Change our message to the invalid response
        message = invalid_response

        # Increment
        counter += 1
      end

      raise ESM::Exception::CheckFailure, I18n.t("failure_to_communicate") if match.nil?

      # Return the match
      match[1]
    end

    private

    def load_community_prefixes
      @prefixes = {}
      @prefixes.default = ESM.config.prefix

      ESM::Community.all.each do |community|
        next if community.command_prefix.nil?

        @prefixes[community.guild_id] = community.command_prefix
      end
    end

    def determine_activation_prefix(message)
      # The default for @prefixes is the config prefix (NOT NIL)
      prefix = @prefixes[message.channel&.server&.id.to_s]
      return nil if !message.content.start_with?(prefix)

      message.content[prefix.size..-1]
    end

    def format_invalid_response(expected)
      expected_string = expected.map { |value| "`#{value}`" }.join(" or ")
      I18n.t("invalid_response", expected: expected_string)
    end

    # @private
    # Channel can be any of the following: An CommandEvent, a Channel, a User/Member, or a String (Channel, or user)
    def determine_delivery_channel(channel)
      return nil if channel.nil?

      if channel.is_a?(Discordrb::Commands::CommandEvent)
        channel.channel
      elsif channel.is_a?(Discordrb::Channel)
        channel
      elsif channel.is_a?(Discordrb::Member) || channel.is_a?(Discordrb::User)
        channel.pm
      elsif channel.is_a?(String)
        # Try checking if it's a text channel
        temp_channel = self.channel(channel)

        return temp_channel if temp_channel.present?

        # Okay, it might be a PM channel, just go with it regardless (it returns nil)
        self.pm_channel(channel)
      end
    end
  end
end
