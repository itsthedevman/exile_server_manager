# frozen_string_literal: true

RSpec.shared_context("command") do
  attr_reader :previous_command

  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user(*(respond_to?(:user_args) ? user_args : [])) }
  let(:command_class) { described_class } # This can be overwritten
  let(:command) { @previous_command || command_class.new }
  let(:server) { ESM::Test.server }
  let(:second_user) { ESM::Test.user }

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

    channel =
      if (channel = opts.delete(:channel))
        channel
      elsif ESM::Command::Base::TEXT_CHANNEL_TYPES.include?(channel_type)
        ESM::Test.data[user.guild_type][:channels].sample
      else
        user.discord_user.pm.id
      end

    channel = ESM.bot.channel(channel) unless channel.is_a?(Discordrb::Channel)

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
              value
            end

          {name: argument.display_name.to_s, value: value, type: argument.discord_type}
        end

      data[:data][:options] = [{type: 1, name: command.command_name, options: options}]
    end

    respond_to_prompt(prompt_response) if prompt_response

    event = Discordrb::Events::ApplicationCommandEvent.new(data.deep_stringify_keys, ESM.bot)

    # In normal operation, #event_hook will receive the ApplicationCommandEvent above
    # SpecApplicationCommandEvent overwrites `#defer` and `#edit_response` to avoid
    # sending those calls to Discord proper
    if handle_error
      # Allows commands to access this command after it has been used
      @previous_command = command_class.event_hook(SpecApplicationCommandEvent.new(event))
      return
    end

    event = ESM::Event::ApplicationCommand.new(event)
    @previous_command = command_class.new(
      user: event.user,
      server: event.server,
      channel: event.channel,
      arguments: event.options
    )

    @previous_command.from_discord!
  end

  def wait_for_completion!(event = :on_execute)
    wait_for { previous_command.timers.public_send(event.to_sym).finished? }.to be(true)
  end

  def respond_to_prompt(response)
    ESM::Test.response = response
  end
end
