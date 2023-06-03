RSpec.shared_context("command") do
  let!(:command) { (respond_to?(:command_class) ? command_class : described_class).new }
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let(:server) { ESM::Test.server }
  let(:second_user) { ESM::Test.user }

  #
  # Executes the command as a user in a text or pm channel.
  # The majority of the time, this method will be used along with the input arguments for the command
  #
  # @param fail_on_raise [Boolean] Controls if the spec will fail if the execute raises an exception. Default: true
  # @param channel_type [Symbol] Controls what type of channel messages are triggered in. Options: :text, :pm
  # @param send_as [ESM::User] The user to send the message as. Defaults to the `user` let binding
  # @param command_override [ESM::Command] The command to execute. Defaults to the `command` let binding
  # @param channel [Discordrb::Channel, nil] The channel to execute the command in
  # @param **command_args [Hash] Any arguments the command is expecting as key: value pairs
  #
  def execute!(**opts)
    fail_on_raise = opts.delete(:fail_on_raise)
    channel_type = opts.delete(:channel_type) || :text
    send_as_user = opts.delete(:send_as) || user
    command = opts.delete(:command) || self.command
    channel = opts.delete(:channel)

    command_statement = command.statement(**opts)
    event = CommandEvent.create(
      command_statement,
      user: send_as_user,
      channel_type: channel_type,
      channel: channel
    )

    # By default
    if fail_on_raise.nil? || fail_on_raise
      result =
        begin
          command.execute(event)
        rescue => e
          error!(error: e)
          e
        end

      expect(result).not_to be_kind_of(StandardError)

      result
    else
      command.execute(event)
    end
  end

  def wait_for_completion!(event = :on_execute)
    wait_for { command.timers.public_send(event.to_sym).finished? }.to be(true)
  end
end
