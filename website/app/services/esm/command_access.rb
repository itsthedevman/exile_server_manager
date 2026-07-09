# frozen_string_literal: true

module ESM
  ##
  # Website-side adapter over {ESM::Command::Permission}.
  #
  class CommandAccess
    # @param command_name [String] the canonical command name (e.g. "gamble"), the key both CommandConfiguration and
    #   Cooldown share across surfaces
    # @param user [ESM::User] the player attempting the command
    # @param server [ESM::Server] the server the command runs against
    def initialize(command_name:, user:, server:)
      @command = ESM::Command[command_name]
      @user = user
      @server = server
    end

    ##
    # The permission verdict for this user running this command against this server: registration, the community's
    # enable/allowlist configuration, and server connectivity. Cooldown is not part of the verdict - it's a command
    # cooldown, owned and enforced by the service handler (checked before the work, applied only on success), never by
    # the website.
    #
    # @return [ESM::Command::Permission::Result]
    #
    def verdict
      membership = community.membership_for(user)

      permission.resolve(
        role_ids: membership.role_ids,
        administrator: membership.administrator,
        server_online: server.connected?
      )
    end

    private

    attr_reader :command, :user, :server

    def community
      @community ||= server.community
    end

    def permission
      @permission ||= ESM::Command::Permission.new(command:, user:, community:)
    end
  end
end
