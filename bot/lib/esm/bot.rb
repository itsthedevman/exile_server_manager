# frozen_string_literal: true

module ESM
  class Bot < Discordrb::Commands::CommandBot
    # View Channels
    # Send Messages
    # Embed Links
    # Attach Files
    # Add Reactions
    PERMISSION_BITS = 52_288

    STATUS_TYPES = {
      PLAYING: 0,
      STREAMING: 1,
      LISTENING: 2,
      WATCHING: 3
    }.freeze

    INTENTS = Discordrb::INTENTS.slice(
      :servers,
      :server_members,
      # :server_bans,
      # :server_emojis,
      # :server_integrations,
      # :server_webhooks,
      # :server_invites,
      # :server_voice_states,
      # :server_presences,
      :server_messages,
      # :server_message_reactions,
      :server_message_typing,
      :direct_messages,
      # :direct_message_reactions,
      :direct_message_typing
    ).keys.freeze

    attr_reader :config, :prefix

    def initialize
      @prefixes = {}
      @prefixes.default = ESM.config.prefix

      # Connect to the database
      ESM::Database.connect!

      load_community_prefixes

      super(
        token: ESM.config.token,
        prefix: method(:determine_activation_prefix),
        help_command: false,
        intents: INTENTS
      )
    end

    def run
      # Binds the Discord Events
      bind_events!

      # Register all of ESM's commands
      ESM::Command.load_commands

      # Call Discordrb::Commands::Commandbot.run
      super
    end

    def stop
      return if stopping?

      @esm_status = :stopping
      ESM::Websocket::Server.stop
      ESM::Request::Overseer.die

      super
    end

    # Overriding DiscordRB's variant to allow commands to be case-insensitive
    #
    # @override
    def simple_execute(chain, event)
      return nil if chain.empty?

      args = chain.split(" ")
      execute_command(args[0].downcase.to_sym, event, args[1..])
    end

    ###########################
    # Discord Events!
    # These all have to have unique-to-ESM names since we are inheriting
    ###########################
    def bind_events!
      mention(&method(:esm_mention))
      ready(&method(:esm_ready))
      server_create(&method(:esm_server_create))
      user_ban(&method(:esm_user_ban))
      user_unban(&method(:esm_user_unban))
      member_join(&method(:esm_member_join))
    end

    def esm_mention(_event)
      # This event is raised when the bot is mentioned in a message.
    end

    def esm_ready(_event)
      ESM::Notifications.trigger("ready")

      bot_attributes = ESM::BotAttribute.first

      # status, activity, url, since = 0, afk = false, activity_type = 0
      update_status("online", bot_attributes.status_message, nil, activity_type: STATUS_TYPES[bot_attributes.status_type]) if bot_attributes.present?

      # Sometimes the bot loses connection with Discord. Upon reconnect, the ready event will be triggered again.
      # Don't restart the websocket server again.
      return if ready?

      # Wait until the bot has connected before starting the websocket.
      # This is to avoid servers connecting before the bot is ready
      ESM::API.run!
      ESM::Websocket.start!
      ESM::Request::Overseer.watch

      @esm_status = :ready
    end

    def esm_server_create(event)
      # This event is raised when a server is created respective to the bot
      ESM::Event::ServerCreate.new(event.server).run!
    end

    def esm_user_ban(event)
      # This event is raised when a user is banned from a server.
      # IDEA: Ask the banning admin if they would also like to ban the user on the server
    end

    def esm_user_unban(event)
      # This event is raised when a user is unbanned from a server.
    end

    # Fires when a member joins a Discord server
    def esm_member_join(event)
      return if ESM.env.development? && ESM.config.dev_user_whitelist.include?(event.user.id.to_s)

      ESM::Event::MemberJoin.new(event).run!
    end

    ###########################
    # Public Methods
    ###########################
    def channel_permission?(permission, channel)
      profile.on(channel.server)&.permission?(permission, channel) || false
    end

    def stopping?
      @esm_status == :stopping
    end

    def ready?
      @esm_status == :ready
    end

    #
    # Sends a message via the bot to a channel
    #
    # @param message [String, ESM::Embed] A message or embed to send
    # @param to [String, Discordrb::Commands::CommandEvent, Discordrb::Channel, Discordrb::Member, Discordrb::User] Where should the message be sent? This ultimately will end up as a channel
    # @param embed_message [String] An optional message to attach with an embed. Only works if `message` is an embed
    # @param replying_to [Discordrb::Message] A message to "reply" to. Discord will reference the previous message
    #
    # @return [Discordrb::Message, nil] The message response or nil if it failed
    #
    def deliver(message, to:, embed_message: "", replying_to: nil)
      return if message.blank?

      replying_to = nil if replying_to.present? && !replying_to.is_a?(Discordrb::Message)
      message = message.join("\n") if message.is_a?(Array)

      delivery_channel = determine_delivery_channel(to)
      raise ESM::Exception::ChannelNotFound.new(message, to) if delivery_channel.nil?

      ESM::Notifications.trigger("bot_deliver", message: message, channel: delivery_channel)

      # So we can test if it's working
      # env.error_testing? is to allow testing of errors without sending messages
      if ESM.env.test? || ESM.env.error_testing?
        ESM::Test.messages.store(message, delivery_channel)
      elsif message.is_a?(ESM::Embed)
        # Send the embed
        delivery_channel.send_embed(embed_message, nil, nil, false, nil, replying_to) { |embed| message.transfer(embed) }
      else
        # Send the text message
        delivery_channel.send_message(message, false, nil, nil, nil, replying_to)
      end
    rescue => e
      ESM.logger.warn("#{self.class}##{__method__}") { "Send failed!\n#{e.message}\n#{e.backtrace[0..5].join("\n\t")}" }
      nil
    end

    def deliver_and_await!(message, to:, expected:, owner: to, invalid_response: nil, timeout: nil, give_up_after: 99)
      counter = 0
      match = nil
      invalid_response = format_invalid_response(expected) if invalid_response.nil?
      channel = determine_delivery_channel(to)
      owner = user(owner)

      while match.nil? && counter < give_up_after
        deliver(message, to: channel)

        response =
          if ESM.env.test?
            ESM::Test.await
          else
            # Add the await event
            owner.await!(timeout: timeout)
          end

        # We timed out, return nil
        return nil if response.nil?

        # Parse the match from the event
        match = response.message.content.match(Regexp.new("(#{expected.map(&:downcase).join("|")})", Regexp::IGNORECASE))

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

    def update_community_prefix(community)
      @prefixes[community.guild_id] = community.command_prefix
    end

    # Channel can be any of the following: An CommandEvent, a Channel, a User/Member, or a String (Channel, or user)
    def determine_delivery_channel(channel)
      return nil if channel.nil?

      case channel
      when Discordrb::Commands::CommandEvent
        channel.channel
      when Discordrb::Channel
        channel
      when Discordrb::Member, Discordrb::User
        channel.pm
      when String
        # Try checking if it's a text channel
        temp_channel = self.channel(channel)

        return temp_channel if temp_channel.present?

        # Okay, it might be a PM channel, just go with it regardless (it returns nil)
        pm_channel(channel)
      end
    end

    def update_prefix(community)
      @prefixes[community.guild_id] = community.command_prefix || ESM.config.prefix
    end

    private

    def load_community_prefixes
      ESM::Community.all.each do |community|
        next if community.command_prefix.nil?

        @prefixes[community.guild_id] = community.command_prefix
      end
    end

    def determine_activation_prefix(message)
      # The default for @prefixes is the config prefix (NOT NIL)
      prefix = @prefixes[message.channel&.server&.id.to_s]
      return nil if !message.content.start_with?(prefix)

      message.content[prefix.size..]
    end

    def format_invalid_response(expected)
      expected_string = expected.map { |value| "`#{value}`" }.join(" or ")
      I18n.t("invalid_response", expected: expected_string)
    end
  end
end
