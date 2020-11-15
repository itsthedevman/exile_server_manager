# frozen_string_literal: true

module ESM
  class Bot < Discordrb::Commands::CommandBot
    IGNORED_EVENTS = %i[
      MESSAGE_REACTION_ADD
      MESSAGE_REACTION_REMOVE
      MESSAGE_REACTION_REMOVE_ALL
      PRESENCE_UPDATE
      VOICE_SERVER_UPDATE
      GUILD_ROLE_DELETE
      GUILD_EMOJIS_UPDATE
    ].freeze

    # View Channels
    # Send Messages
    # Embed Links
    # Attach Files
    # Add Reactions
    PERMISSION_BITS = 52_288

    STATUS_TYPES = {
      "PLAYING": 0,
      "STREAMING": 1,
      "LISTENING": 2,
      "WATCHING": 3
    }.freeze

    attr_reader :config, :prefix

    attr_reader :resend_queue if ESM.env.test?

    def initialize
      # Connect to the database
      ESM::Database.connect!

      load_community_prefixes

      @resend_queue = ESM::Bot::ResendQueue.new(self)

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

    # Allows me to not load PRESENCE_UPDATES and such.
    # Discordrb::Gateway
    #                   .handle_message ->
    #                   .handle_dispatch ->
    # Discordrb::Bot
    #                   .dispatch ->
    #                   .handle_dispatch
    def handle_dispatch(type, data)
      super(type, data) if !IGNORED_EVENTS.include?(type)
    end

    # Overriding DiscordRB's variant to allow commands to be case-insensitive
    #
    # @override
    def simple_execute(chain, event)
      return nil if chain.empty?

      args = chain.split(' ')
      execute_command(args[0].downcase.to_sym, event, args[1..-1])
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
      self.member_join(&method(:esm_member_join))
    end

    # This event is raised when the bot has disconnected from the WebSocket, due to the Bot#stop method or external causes.
    def esm_disconnected(_event)
      ESM.logger.info("#{self.class}##{__method__}") { "Disconnected event called!" }

      # IDEA: Maybe send email?
      ESM::Request::Overseer.die
      ESM::Websocket::Server.stop

      @resend_queue.die if @resend_queue.present?
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
      return if self.ready?

      # Wait until the bot has connected before starting the websocket.
      # This is to avoid servers connecting before the bot is ready
      ESM::API.run!
      ESM::Websocket.start!
      ESM::Request::Overseer.watch

      @ready = true
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
      return if ESM.env.development? && event.user.id.to_s != ESM::User::BryanV2::ID

      ESM::Event::MemberJoin.new(event).run!
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

      ESM::Notifications.trigger("bot_deliver", message: message, channel: delivery_channel)

      # So we can test if it's working
      # env.error_testing? is to allow testing of errors without sending messages
      return ESM::Test.messages.store(message, to, delivery_channel) if ESM.env.test? || ESM.env.error_testing?

      discord_message =
        if message.is_a?(ESM::Embed)
          # Send the embed
          delivery_channel.send_embed { |embed| message.transfer(embed) }
        else
          # Send the text message
          delivery_channel.send_message(message)
        end

      # Dequeue the message if it was enqueued
      @resend_queue.dequeue(message, to: to)

      # Return the Discordrb::Message
      discord_message
    rescue StandardError => e
      ESM.logger.warn("#{self.class}##{__method__}") { "Send failed!\n#{e.message}" }
      @resend_queue.enqueue(message, to: to, exception: e)
    end

    def deliver_and_await!(message, to:, owner: to, expected:, invalid_response: nil, timeout: nil, give_up_after: 99)
      counter = 0
      match = nil
      invalid_response = format_invalid_response(expected) if invalid_response.nil?
      channel = determine_delivery_channel(to)
      owner = self.user(owner)

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
        self.pm_channel(channel)
      end
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

      message.content[prefix.size..]
    end

    def format_invalid_response(expected)
      expected_string = expected.map { |value| "`#{value}`" }.join(" or ")
      I18n.t("invalid_response", expected: expected_string)
    end
  end
end
