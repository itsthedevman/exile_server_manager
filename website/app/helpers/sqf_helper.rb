# frozen_string_literal: true

module SqfHelper
  ##
  # URL the result poller watches until a dispatched SQF command settles. The command carries its own server, so a
  # caller holding only the command can still build it.
  #
  # @param command [ESM::ServiceCommand] the dispatched SQF command
  #
  # @return [String] the command's status endpoint path
  #
  def sqf_command_status_path(command)
    command_status_server_sqf_path(command.server.public_id, command)
  end
end
