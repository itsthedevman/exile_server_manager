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

    def self.register_command(command_class)
      ESM.bot&.command(command_class.name.to_sym, aliases: command_class.aliases) do |event|
        # Execute the command.
        # Threaded since I handle everything in the commands
        Thread.new { command_class.new.execute(event) }

        # Don't send anything back
        nil
      end
    end

    attr_reader :config, :prefix, :metadata

    def initialize
      @waiting_for = {}
      @mutex = Mutex.new

      @prefixes = {}
      @prefixes.default = ESM.config.prefix

      load_community_prefixes

      super(
        token: ESM.config.token,
        prefix: method(:determine_activation_prefix),
        help_command: false,
        intents: INTENTS
      )
    end

    def run
      ESM::Command.load unless ESM.env.test?

      # Binds the Discord Events
      bind_events!

      # Call Discordrb::Commands::Commandbot.run
      super
    end

    def stop
      return if stopping?

      @esm_status = :stopping
      ESM::Websocket::Server.stop
      ESM::Connection::Server.stop!
      ESM::Request::Overseer.die

      super

      exit
    end

    # Overriding DiscordRB's variant to allow commands to be case-insensitive
    def simple_execute(chain, event)
      return nil if chain.empty?

      args = chain.split
      execute_command(args[0].downcase.to_sym, event, args[1..])
    end

    ###########################
    # Discord Events!
    # These all have to have unique-to-ESM names since we are inheriting
    ###########################
    def bind_events!
      mention { |event| esm_mention(event) }
      ready { |event| esm_ready(event) }
      server_create { |event| esm_server_create(event) }
      user_ban { |event| esm_user_ban(event) }
      user_unban { |event| esm_user_unban(event) }
      member_join { |event| esm_member_join(event) }
    end

    def esm_mention(_event)
      # This event is raised when the bot is mentioned in a message.
    end

    def esm_ready(_event)
      ESM::Notifications.trigger("ready")

      @metadata = ESM::BotAttribute.first_or_create

      if metadata.present?
        update_status(
          # status
          "online",
          # activity
          metadata.status_message,
          # url
          nil,
          # since: 0
          # afk: 0
          activity_type: STATUS_TYPES[metadata.status_type]
        )
      end

      # Sometimes the bot loses connection with Discord. Upon reconnect, the ready event will be triggered again.
      # Don't restart the websocket server again.
      return if ready?

      # Wait until the bot has connected before starting the websocket.
      # This is to avoid servers connecting before the bot is ready
      ESM::API.run!

      # V1
      ESM::Websocket.start!
      ESM::Request::Overseer.watch
      # V1

      ESM::Connection::Server.run!

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

    #
    # Checks if the bot has send permission to the provided channel
    #
    # @param permission [Symbol] The permission to check
    # @param channel [Discordrb::Channel] The channel to check
    #
    # @return [Boolean]
    #
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

      if !delivery_channel.pm?
        raise ESM::Exception::ChannelAccessDenied if !channel_permission?(:read_messages, delivery_channel)
        raise ESM::Exception::ChannelAccessDenied if !channel_permission?(:send_messages, delivery_channel)
      end

      ESM::Notifications.trigger("bot_deliver", message: message, channel: delivery_channel)

      if message.is_a?(ESM::Embed)
        # Send the embed
        delivery_channel.send_embed(embed_message, nil, nil, false, nil, replying_to) { |embed| message.transfer(embed) }
      else
        # Send the text message
        delivery_channel.send_message(message, false, nil, nil, nil, replying_to)
      end
    rescue ESM::Exception::ChannelAccessDenied
      embed = ESM::Embed.build(
        :error,
        description: I18n.t("exceptions.deliver_failure", channel_name: delivery_channel.name, message: message)
      )

      community = ESM::Community.find_by_guild_id(delivery_channel.server.id)
      community.log_event(:error, embed)

      nil
    rescue => e
      warn!(error: e)

      nil
    end

    # Also see #wait_for_reply
    def await_response(responding_user, expected:, timeout: nil)
      counter = 0
      match = nil
      invalid_response = format_invalid_response(expected)
      responding_user = user(responding_user)

      while match.nil? && counter < 99
        response =
          if ESM.env.test?
            ESM::Test.wait_for_response(timeout: timeout)
          else
            # Add the await event
            responding_user.await!(timeout: timeout)
          end

        # We timed out
        break if response.nil?

        # Parse the match from the event
        match = response.message.content.match(Regexp.new("(#{expected.map(&:downcase).join("|")})", Regexp::IGNORECASE))

        # We found what we were looking for
        break if !match.nil?

        # Let the user know that was not quite what we were looking for
        deliver(invalid_response, to: responding_user)

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
      return if channel.nil?

      case channel
      when Discordrb::Commands::CommandEvent
        channel.channel
      when Discordrb::Channel
        channel
      when ESM::User
        channel.discord_user.pm
      when Discordrb::Member, Discordrb::User
        channel.pm
      when String, Numeric
        # Try checking if it's a text channel
        temp_channel = self.channel(channel)

        # Okay, it might be a PM channel, just go with it regardless (it returns nil)
        if temp_channel.nil?
          pm_channel(channel)
        else
          temp_channel
        end
      end
    end

    def update_prefix(community)
      @prefixes[community.guild_id] = community.command_prefix || ESM.config.prefix
    end

    #
    # Successor to #await_response. Waits for an event from user_id and channel_id
    #
    # @param user_id [Integer/String] The ID of the user who sends the message
    # @param channel_id [Integer/String] The ID of the channel where the message is sent to. The bot must be a member of said channel
    # @param expires_at [DateTime, Time] When this time is reached, the callback will be called with `nil` for the event
    # @param &callback [Proc] The code to execute once the message has been received
    #
    # @return [true]
    #
    def wait_for_reply(user_id:, channel_id:, expires_at: 5.minutes.from_now, &callback)
      @mutex.synchronize do
        @waiting_for[user_id] ||= []
        @waiting_for[user_id] << channel_id
      end

      # Event will be nil if it times out
      timeout = expires_at - ::Time.now
      event =
        if ESM.env.test?
          ESM::Test.wait_for_response(timeout: timeout)
        else
          add_await!(Discordrb::Events::MessageEvent, {from: user_id, in: channel_id, timeout: timeout})
        end

      @mutex.synchronize do
        @waiting_for[user_id]&.delete_if { |id| id == channel_id }
      end

      return event unless callback

      yield(event)
      nil
    end

    def waiting_for_reply?(user_id:, channel_id:)
      @mutex.synchronize do
        channel_ids = @waiting_for[user_id]
        return false if channel_ids.blank?

        channel_ids.include?(channel_id)
      end
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
      return if !message.content.start_with?(prefix)

      message.content[prefix.size..]
    end

    def format_invalid_response(expected)
      expected_string = expected.map { |value| "`#{value}`" }.join(" or ")
      I18n.t("invalid_response", expected: expected_string)
    end
  end
end
