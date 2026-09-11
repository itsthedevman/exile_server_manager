# frozen_string_literal: true

module ESM
  ##
  # Website-side adapter over {ESM::Command::Permission}.
  #
  class CommandAccess
    NOT_A_MEMBER = ESM::Command::Permission::Result.new(reason: :not_a_member, detail: nil).freeze

    # @param command_name [String] the canonical command name (e.g. "gamble"), the key both CommandConfiguration and
    #   Cooldown share across surfaces
    # @param user [ESM::User] the player attempting the command
    # @param community [ESM::Community, nil] the community the command runs against; read off the server when omitted
    # @param server [ESM::Server, nil] the server the command targets, for the commands that target one
    #
    # @raise [ArgumentError] when neither argument names a community to gate against
    def initialize(command_name:, user:, community: nil, server: nil)
      community ||= server&.community
      raise ArgumentError, "gating #{command_name} needs a community or a server that belongs to one" if community.nil?

      @command = ESM::Command[command_name]
      @user = user
      @community = community
      @server = server
    end

    ##
    # The permission verdict for this user running this command: registration, the community's enable/allowlist
    # configuration, and - for a command that targets a server - that server's connectivity. A community-scoped command
    # has no server to ask about, so it reports nil connectivity and the resolver skips that gate; this is how Discord
    # already reads it, where check_for_connected_server! returns early for a command carrying no server_id.
    #
    # Cooldown is not part of the verdict - it's a command cooldown, owned and enforced by the service handler (checked
    # before the work, applied only on success), never by the website.
    #
    # Membership comes first for a command Discord only accepts in a text channel. Discord pins that channel to the
    # command's own community, so only a member of the guild can ever run it there, and turning its allowlist off opens
    # it to members rather than to everyone. A command that also runs from a DM draws no such line on Discord, and draws
    # none here.
    #
    # @return [ESM::Command::Permission::Result]
    #
    def verdict
      membership = community.membership_for(user)
      return NOT_A_MEMBER if membership.nil? && command.limited_to == :text

      permission.resolve(
        role_ids: membership&.role_ids || [],
        administrator: membership&.administrator || false,
        server_online: server&.connected?
      )
    end

    private

    attr_reader :command, :user, :community, :server

    def permission
      @permission ||= ESM::Command::Permission.new(command:, user:, community:)
    end
  end
end
