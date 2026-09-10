# frozen_string_literal: true

module ESM
  class Cooldown < ApplicationRecord
    # =============================================================================
    # INITIALIZE
    # =============================================================================

    TYPES = %w[times seconds minutes hours days].freeze

    # =============================================================================
    # DATA STRUCTURE
    # =============================================================================

    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :user_id, :integer
    attribute :steam_uid, :string
    attribute :command_name, :string
    attribute :cooldown_quantity, :integer, default: 1
    attribute :cooldown_type, :string, default: "seconds"
    attribute :cooldown_amount, :integer, default: 0
    attribute :scope_key, :string
    attribute :expires_at, :datetime, default: -> { 1.second.ago }
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    # =============================================================================
    # ASSOCIATIONS
    # =============================================================================

    # A row carries only one of user_id or steam_uid, and a community-scoped command has no server to pin its
    # cooldown to, so both of these are legitimately null on rows the handler writes every day. Only the community
    # is always present.
    belongs_to :user, optional: true
    belongs_to :server, optional: true
    belongs_to :community

    # =============================================================================
    # VALIDATIONS
    # =============================================================================

    # =============================================================================
    # CALLBACKS
    # =============================================================================

    # =============================================================================
    # SCOPES
    # =============================================================================

    ##
    # The rows a player is actually being held back by right now, asked as SQL rather than as a predicate over rows
    # already loaded.
    #
    # A community accumulates one row per command per player per server and never deletes any, so a surface that
    # lists cooldowns has to narrow before it loads rather than after. Reads as the SQL half of {#active?} and has to
    # keep agreeing with it; the pair is covered by a spec that runs both over the same rows.
    #
    scope :active, -> {
      where(
        "(cooldown_type = 'times' AND cooldown_amount >= cooldown_quantity) " \
        "OR (cooldown_type != 'times' AND expires_at >= ?)",
        ::Time.current
      )
    }

    # =============================================================================
    # CLASS METHODS
    # =============================================================================

    ##
    # The cooldown rows for one player running one command, scoped the single way both the bot and the website look
    # them up so the two surfaces can't drift into separate throttles. Registration-gated commands key on steam_uid (the
    # throttle follows the player); everything else keys on user_id. community and server narrow the scope when the
    # command targets them.
    #
    # @param command_name [String] the command the cooldown governs
    # @param user [ESM::User] the player being throttled
    # @param registered [Boolean] whether the command requires registration (steam_uid key)
    # @param community [ESM::Community, nil] the target community, when the command has one
    # @param server [ESM::Server, nil] the target server, when the command has one
    # @param scope_key [String, Symbol, nil] the slice of the command the cooldown governs, such as a reward package's
    #   ID. nil means the command's own cooldown, and it matches only rows that are themselves unscoped
    #
    # @return [ActiveRecord::Relation] the scoped cooldowns
    #
    def self.scope_for(command_name:, user:, registered:, community: nil, server: nil, scope_key: nil)
      # Always filtered, including on nil. Skipping it for nil would let a command's own lookup pull back one of its
      # scoped rows, which the unique indexes already treat as a separate cooldown.
      query = where(command_name:, scope_key:)
      query = registered ? query.where(steam_uid: user.steam_uid) : query.where(user_id: user.id)
      query = query.where(community_id: community.id) if community
      query = query.where(server_id: server.id) if server
      query
    end

    ##
    # Bring every cooldown governed by a command configuration back in line with it. Called when a community edits the
    # command's cooldown, so that every reader still pulls a correct row without normalizing at the call site - the
    # correction now happens once, at the edit that made the rows stale, instead of on every read.
    #
    # @param configuration [ESM::CommandConfiguration] the just-changed configuration
    #
    # @return [void]
    #
    def self.reconcile_to(configuration)
      # Scoped rows answer to a per-scope configuration the server owner controls, such as a reward package's own
      # cooldown, so a community editing the command's cooldown must not overwrite them.
      where(command_name: configuration.command_name, community_id: configuration.community_id, scope_key: nil)
        .find_each { |cooldown| cooldown.reconcile_to!(configuration) }
    end

    ##
    # Decompose a duration into a time-based row's stored shape: 2.seconds becomes
    # {cooldown_type: "seconds", cooldown_quantity: 2, expires_at: executed_at + 2s}.
    #
    # @param executed_at [Time] the moment the cooldown starts counting from
    # @param duration [ActiveSupport::Duration] the cooldown length
    #
    # @return [Hash] the attributes to write for the cooldown
    #
    def self.expiry_attributes(executed_at, duration)
      # 2.seconds -> [:seconds, 2]
      type, quantity = duration.parts.to_a.first

      {cooldown_type: type.to_s, cooldown_quantity: quantity, expires_at: (executed_at + duration).to_time}
    end

    # =============================================================================
    # INSTANCE METHODS
    # =============================================================================

    def user
      return ESM::User.where(id: user_id).first if user_id.present?
      return ESM::User.find_by_steam_uid(steam_uid) if steam_uid.present?

      nil
    end

    def active?
      if cooldown_type == "times"
        cooldown_amount >= cooldown_quantity
      else
        expires_at >= ::Time.current
      end
    end

    def to_s
      ESM::Time.distance_of_time_in_words(expires_at)
    end

    def reset!
      update!(expires_at: 5.seconds.ago, cooldown_amount: 0)
    end

    def update_expiry!(executed_at, cooldown_time)
      case cooldown_time
      # 1.times, 5.times...
      when Enumerator, Integer
        update!(
          cooldown_quantity: cooldown_time.is_a?(Integer) ? cooldown_time : cooldown_time.size,
          cooldown_type: "times",
          cooldown_amount: cooldown_amount + 1
        )
      # 1.second, 5.days
      when ActiveSupport::Duration
        update!(self.class.expiry_attributes(executed_at, cooldown_time))
      end
    end

    ##
    # Re-align this row to a command configuration: sync its stored type and quantity, shorten the remaining window when
    # the new cooldown is smaller, and reset when the change crosses the times<->duration boundary. Only ever gives time
    # back - a larger new cooldown never retroactively lengthens someone's current wait.
    #
    # @param configuration [ESM::CommandConfiguration] the configuration to match
    #
    # @return [void]
    #
    def reconcile_to!(configuration)
      return if configuration.cooldown_type == cooldown_type && configuration.cooldown_quantity == cooldown_quantity

      # Crossing into or out of a usage-count cooldown has no comparable window, so start the new one clean rather than
      # trying to translate the old one.
      if configuration.cooldown_type == "times" || cooldown_type == "times"
        self.expires_at = 1.second.ago
        self.cooldown_amount = 0
      else
        new_cooldown_seconds = configuration.cooldown_quantity.send(configuration.cooldown_type).to_i
        current_cooldown_seconds = cooldown_quantity.send(cooldown_type).to_i

        self.expires_at = expires_at - (current_cooldown_seconds - new_cooldown_seconds) if new_cooldown_seconds < current_cooldown_seconds
      end

      self.cooldown_type = configuration.cooldown_type
      self.cooldown_quantity = configuration.cooldown_quantity
      save!
    end
  end
end
