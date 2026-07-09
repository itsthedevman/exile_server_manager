# frozen_string_literal: true

RSpec.shared_context("command") do
  attr_reader :previous_command

  # Override in a spec when the user must be the discord_server's owner.
  let(:user_is_owner) { false }

  let(:discord_user) { build(:discord_user) }
  let(:discord_server) do
    build(
      :discord_server,
      :with_command_channels,
      owner: user_is_owner ? discord_user : build(:discord_user)
    )
  end

  let!(:community) { create(:community, discord_server: discord_server) }
  let!(:user) do
    args = respond_to?(:user_args) ? user_args : []

    # When the user is the server owner, the discord_server factory has
    # already registered them as a member; using :with_discord_member would
    # double-register.
    user =
      if user_is_owner
        create(:user, *args, discord_user: discord_user)
      else
        create(:user, :with_discord_member, *args, discord_user: discord_user, discord_server: discord_server)
      end

    community.update!(owner_user_id: user.id) if user_is_owner
    user
  end
  let(:command_class) { described_class }
  let(:command) { @previous_command || command_class.new }
  let(:server) { create(:server, community_id: community.id) }
  let(:second_user) { create(:user, :with_discord_member, discord_server: discord_server) }
  let(:default_text_channel) { discord_server.channels.find { |channel| channel.name == "general" } || discord_server.channels.first }

  #
  # Executes the command as a user in a text or pm channel.
  # The majority of the time, this method will be used along with the input arguments for the command
  #
  # @param channel_type [Symbol] Controls what type of channel messages are triggered in. Options: :text, :pm
  # @param user [ESM::User] The user to send the message as. Defaults to the `user` let binding
  # @param command_override [ESM::Command] The command to execute. Defaults to the `command` let binding
  # @param channel [Discordrb::Channel, nil] The channel to execute the command in
  # @param arguments [Hash] Any arguments the command is expecting as key: value pairs
  # @param prompt_response [String, nil] Optional. The value to set as the user's "response" to ESM prompting them
  # @param handle_error [TrueClass, FalseClass] Controls if errors should be handled by the command or bubbled up
  #   If this is true, the command's `.event_hook` method will be called. Any errors will be handled
  #   if this is false (default), the command's `#execute` method will be called. Any errors will raise in the specs
  #
  def execute!(**opts)
    channel_type = opts.delete(:channel_type) || :text
    send_as = opts.delete(:user) || user
    command_class = opts.delete(:command_class) || self.command_class
    arguments = opts.delete(:arguments) || {}
    prompt_response = opts.delete(:prompt_response)
    handle_error = opts.delete(:handle_error)
    command = command_class.new

    channel =
      if (override = opts.delete(:channel))
        override
      elsif ESM::Command::Base::TEXT_CHANNEL_TYPES.include?(channel_type)
        default_text_channel
      else
        send_as.discord_user.pm
      end

    channel = ESM.discord_bot.channel(channel) unless channel.is_a?(Discordrb::Channel)

    data = {
      id: "", # ID of interaction
      application_id: "", # Bot id?
      type: 2, # Interaction type. 2 is command
      data: {
        id: "", # Command ID
        name: command.command_name # Command name
      },
      guild_id: channel.server&.id, # Server ID
      channel_id: channel.id, # Channel ID
      user: {
        id: send_as.discord_id # User ID
      },
      token: ESM.config.token, # Bot token
      version: 1 # IDK
    }

    if command.arguments.size > 0 && arguments.size > 0
      options =
        arguments.map do |key, value|
          argument = command.arguments.template(key)
          raise ArgumentError, "Invalid argument \"#{key}\" given for #{command.class}" if argument.nil?

          value =
            case value
            when ESM::Server
              value.server_id
            when ESM::Community
              value.community_id
            when ESM::User
              value.mention
            else
              # All values from Discord are sent as String
              value.to_s
            end

          {name: argument.display_name.to_s, value: value, type: Discordrb::Interactions::OptionBuilder::TYPES[argument.type]}
        end

      data[:data][:options] = [{type: 1, name: command.command_name, options: options}]
    end

    respond_to_prompt(prompt_response, user: send_as, channel: channel) if prompt_response

    event = Discordrb::Events::ApplicationCommandEvent.new(data.deep_stringify_keys, ESM.discord_bot)

    # In normal operation, #event_hook will receive the ApplicationCommandEvent above
    # SpecApplicationCommandEvent overwrites `#defer` and `#edit_response` to avoid
    # sending those calls to Discord proper
    if handle_error
      # Allows commands to access this command after it has been used
      @previous_command = command_class.event_hook(SpecApplicationCommandEvent.new(event))
      return
    end

    event = ESM::Discord::Event::ApplicationCommand.new(event)
    origin = ESM::Discord::Command::Origin.new(
      user: ESM::User.from_discord(event.user),
      community: ESM::Community.from_discord(event.server),
      channel: event.channel
    )

    @previous_command = command_class.new(arguments: event.options, origin: origin)

    ESM::Database.with_connection do
      @previous_command.from_discord!
    end
  end

  #
  # Executes the command through the website workflow instead of Discord: mints a ServerCommand row
  # the way the website controller does, drives it through #from_website! via the website event hook,
  # and returns the settled row so specs can assert on its status/result/error_message.
  #
  # @param user [ESM::User] The user to run as. Defaults to the `user` let binding
  # @param command_class [ESM::Command::Base] The command to run. Defaults to the `command_class` let binding
  # @param server [ESM::Server] The target server the row belongs to. Defaults to the `server` let binding
  # @param arguments [Hash] The command arguments, seeded onto the row as Strings the way form params arrive
  #
  # @return [ESM::ServerCommand] the row after it has settled
  #
  def execute_website!(**opts)
    send_as = opts.delete(:user) || user
    command_class = opts.delete(:command_class) || self.command_class
    target_server = opts.delete(:server) || server
    arguments = opts.delete(:arguments) || {}

    # The website delivers every argument as a String (form params), so mirror that on the way in.
    arguments =
      arguments.transform_values do |value|
        case value
        when ESM::Server then value.server_id
        when ESM::Community then value.community_id
        when ESM::User then value.mention
        else value.to_s
        end
      end

    server_command = ESM::ServerCommand.create!(
      user: send_as,
      server: target_server,
      idempotency_key: SecureRandom.uuid,
      command_name: command_class.command_name,
      arguments:,
      status: :pending
    )

    command_class.website_event_hook(server_command)

    server_command.reload
  end

  def wait_for_completion!(event = :on_execute)
    wait_for { previous_command.timers.public_send(event.to_sym).finished? }.to be(true)
  end

  def respond_to_prompt(response, user: discord_user, channel: default_text_channel)
    discord_user_obj = user.respond_to?(:discord_user) ? user.discord_user : user
    ESM.discord_bot.test_inbox.queue_reply(from: discord_user_obj, channel: channel, content: response)
  end

  def accept_request
    previous_command.request.respond(true)
  rescue => e
    return if e.is_a?(ESM::Exception::CheckFailureNoMessage)

    message =
      if e.respond_to?(:to_embed)
        e.to_embed
      else
        e.message
      end

    ESM.discord_bot.deliver(message, to: default_text_channel)
  end
end
