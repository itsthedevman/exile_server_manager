# frozen_string_literal: true

module ESM
  module Command
    ##
    # Resolves whether a user may run a "command".
    #
    class Permission
      ##
      # The outcome of a resolution. A nil reason means the user is allowed; otherwise reason names the first gate that
      # failed and detail carries whatever the caller needs to explain it (e.g. the time left on a cooldown).
      #
      class Result < ::Data.define(:reason, :detail)
        def allowed? = reason.nil?
        def denied? = !allowed?
      end

      ALLOWED = Result.new(reason: nil, detail: nil).freeze

      ##
      # @param command [Class] the command class being gated - the declared source of what the command requires
      #   (registration, allowlist, cooldown) and the defaults used when a community has no override row
      # @param user [ESM::User] the player attempting the command
      # @param community [ESM::Community, nil] the community the command runs against, when it has one
      # @param cooldown [ESM::Cooldown, nil] the user's current cooldown row for the command, when one exists
      def initialize(command:, user:, community: nil, cooldown: nil)
        @command = command
        @user = user
        @community = community
        @cooldown = cooldown
        @configuration = community ? community.command_configurations_lookup[command.command_name] : nil
      end

      ##
      # Runs every gate in priority order and returns the first failure, or ALLOWED when the user clears them all. The
      # order is deliberate: the reason a caller shows is the most fundamental thing standing in the user's way. Every
      # parameter is live, surface-specific state the caller sources for itself - role membership and connectivity are
      # things only the invoking medium can know - while the configuration and identity gates resolve from data this
      # class reads directly.
      #
      # @param role_ids [Array<Integer, String>] the user's Discord role ids in the community
      # @param administrator [Boolean] whether the user holds Discord's administrator permission in the community
      # @param server_online [Boolean, nil] whether the command's target server is currently connected, or nil when the
      #   command targets no server and so has nothing that could be offline
      #
      # @return [Result]
      #
      def resolve(role_ids: [], administrator: false, server_online: nil)
        return denied(:unregistered) if registration_required? && !user.registered?
        return denied(:disabled) unless enabled?
        return denied(:not_allowlisted) unless allowlisted?(role_ids:, administrator:)

        # Only an answered "no" closes this gate. A community-scoped command has no server to ask about, and nil says
        # that rather than claiming a server that doesn't exist is up.
        return denied(:server_offline) if server_online == false
        return denied(:on_cooldown, time_left: cooldown.to_s) if on_cooldown?

        ALLOWED
      end

      def registration_required?
        command.requirements.registration?
      end

      def enabled?
        return configuration.enabled? if configuration

        attribute_default(:enabled, true)
      end

      def allowlist_enabled?
        return configuration.allowlist_enabled? if configuration

        attribute_default(:allowlist_enabled, false)
      end

      def allowlisted_role_ids
        return configuration.allowlisted_role_ids if configuration

        attribute_default(:allowlisted_role_ids, [])
      end

      def cooldown_time
        # [2, "seconds"] -> 2.seconds. Calls .seconds, .minutes, .days, etc.
        return configuration.cooldown_quantity.send(configuration.cooldown_type) if configuration

        attribute_default(:cooldown_time, 2.seconds)
      end

      def notify_when_disabled?
        return configuration.notify_when_disabled? if configuration

        true
      end

      ##
      # Whether the user clears the command's allowlist. A disabled allowlist admits everyone, an administrator always
      # passes, and otherwise at least one of the user's roles must appear on the configured list.
      #
      # @param role_ids [Array<Integer, String>] the user's Discord role ids in the community
      # @param administrator [Boolean] whether the user holds Discord's administrator permission in the community
      #
      # @return [Boolean]
      #
      def allowlisted?(role_ids: [], administrator: false)
        return true unless allowlist_enabled?
        return true if administrator

        configured_ids = allowlisted_role_ids
        return false if configured_ids.empty?

        member_ids = role_ids.map(&:to_i)
        configured_ids.any? { |role_id| member_ids.include?(role_id.to_i) }
      end

      def on_cooldown?
        return false if cooldown.nil?

        cooldown.active?
      end

      private

      attr_reader :command, :user, :community, :cooldown, :configuration

      def attribute_default(name, fallback)
        attribute = command.attributes[name]
        attribute&.default? ? attribute.default : fallback
      end

      def denied(reason, **detail)
        Result.new(reason:, detail: detail.presence)
      end
    end
  end
end
