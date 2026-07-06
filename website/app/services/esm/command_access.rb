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
    # enable/allowlist configuration, and server connectivity. Cooldown is intentionally not part of the verdict - it is
    # enforced atomically at dispatch by {#claim_cooldown!}, never read speculatively, so a rapid double-submit can't
    # slip between a "not on cooldown" read and the write.
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

    ##
    # Atomically reserves the user's cooldown window for this command, using the command's configured cooldown length.
    # Returns false when a live cooldown is already in force; concurrent web requests collapse to a single winner.
    #
    # @return [Boolean] true when this request claimed the window
    #
    def claim_cooldown!
      ESM::Cooldown.claim!(
        command_name: command.command_name,
        user:,
        registered: command.requirements.registration?,
        community:,
        server:,
        duration: permission.cooldown_time
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
