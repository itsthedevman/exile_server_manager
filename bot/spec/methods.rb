# frozen_string_literal: true

#
# Build an ESM::Websocket::Request for V1 websocket specs.
#
# Each call stands up a fresh discord_user + discord_server pair so requests
# don't share identities with anything else in the spec.
#
# @param params [Hash] arbitrary parameters forwarded to the Request
#
# @return [ESM::Websocket::Request]
#
def create_request(**params)
  discord_server = FactoryBot.build(:discord_server, channels: [:general])
  discord_user = FactoryBot.build(:discord_user)
  FactoryBot.build(:discord_member, server: discord_server, user: discord_user)

  ESM::Websocket::Request.new(
    command: ESM::Command::Test::BaseV1.new,
    user: discord_user,
    channel: discord_server.channels.first,
    parameters: params
  )
end

#
# Disable the allowlist on a command for the given community so specs can
# exercise admin commands without configuring roles.
#
# @param community [ESM::Community]
# @param command [String, Symbol] command name (e.g. "broadcast")
#
def grant_command_access!(community, command)
  community.command_configurations.where(command_name: command).update_all(
    allowlist_enabled: false,
    allowed_in_text_channels: true
  )
end

#
# Poll `block` every 100ms until it returns true or `timeout` seconds elapse.
# Replaces `ESM::Test.wait_until` for top-level use in specs.
#
# @param timeout [Numeric] maximum seconds to wait before raising
#
# @yield expected to return a truthy value once the condition is met
#
# @raise [RuntimeError] when the deadline passes without the block returning true. The message names
#   the timeout so the failure is self-explanatory.
#
def wait_until(timeout: 30)
  deadline = Time.now + timeout

  loop do
    sleep 0.1
    return if yield == true
    raise "wait_until: condition not met within #{timeout}s" if Time.now >= deadline
  end
end

#
# All messages captured by the in-memory message store, in insertion order.
#
# @return [Array]
#
def messages
  ESM::Test.messages.contents
end

#
# The first captured message (oldest), or nil when the store is empty.
#
def earliest_message
  ESM::Test.messages.earliest
end

#
# The most recently captured message, or nil when the store is empty.
#
def latest_message
  ESM::Test.messages.latest
end
