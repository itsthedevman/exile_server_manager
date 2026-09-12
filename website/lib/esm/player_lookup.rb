# frozen_string_literal: true

module ESM
  ##
  # Resolves whatever an admin typed into the server hub's player lookup bar.
  #
  # Every identifier the bar accepts except a name names one person, and the Steam UID is the key the player pages are
  # built on, so resolving means answering "whose UID is this". A Discord ID reaches a UID only through ESM
  # registration, which makes it the one input that can dead-end with nowhere to send the admin.
  #
  # Following a Discord ID to a Steam UID is the same pairing whois guards, so it is held to the same line: the account
  # has to be in the community's Discord. Anyone else resolves exactly like an ID ESM has never seen.
  #
  # @example
  #   ESM::PlayerLookup.call("76561198037177305", community:).kind  # => :steam_uid
  #   ESM::PlayerLookup.call("Dave", community:).kind               # => :name
  #
  class PlayerLookup
    # What a query turned out to be. Only :steam_uid and :name lead somewhere; :unregistered and :unknown are the two
    # ways a Discord ID dead-ends, and both are findings worth stating rather than a "no player found".
    KINDS = %i[steam_uid name unregistered unknown blank].freeze

    ##
    # One resolved lookup, carrying the original query so the page that renders it can echo what was asked.
    #
    Result = Datum.define(:kind, :query, :steam_uid, :discord_id) do
      def initialize(kind:, query:, steam_uid: nil, discord_id: nil) = super

      # Not attr_predicate: these ask which kind this is, not whether an attribute of that name holds anything. The
      # two happen to agree for steam_uid, since a Result carries one, and disagree for every other kind.
      KINDS.each do |kind|
        define_method(:"#{kind}?") { self.kind == kind }
      end
    end

    # Anchored to the whole string rather than reusing core's *_ONLY variants, which anchor per line: a pasted value
    # carrying a newline would otherwise satisfy a check its visible text never does.
    STEAM_UID = /\A#{ESM::Regex::STEAM_UID.source}\z/
    DISCORD_ID = /\A#{ESM::Regex::DISCORD_ID.source}\z/
    MENTION = /\A#{ESM::Regex::DISCORD_TAG.source}\z/

    ##
    # @param query [String, nil] Whatever was typed into the lookup bar
    # @param community [ESM::Community] whose Discord a Discord ID has to belong to before it resolves
    #
    # @return [Result] What the query resolved to
    #
    def self.call(query, community:)
      new(query, community:).call
    end

    def initialize(query, community:)
      @query = query.to_s.strip
      @community = community
    end

    ##
    # @return [Result]
    #
    def call
      return result(:blank) if @query.empty?

      # A mention is checked before the bare patterns because its digits are a Discord ID no matter what they look
      # like, and after nothing, because the wrapper is what identifies it.
      return resolve_discord_id if @query.match?(MENTION)
      return result(:steam_uid, steam_uid: @query) if @query.match?(STEAM_UID)
      return resolve_discord_id if @query.match?(DISCORD_ID)

      result(:name)
    end

    private

    # A mention wraps the id in <@ >, sometimes with a ! or & that the id itself does not carry, so the digits are it.
    def discord_id
      @discord_id ||= @query[/\d+/]
    end

    # A non-member answers as :unknown rather than as something of its own. "Not in your Discord" would still tell the
    # admin that ESM knows the account, which is a question about someone with no connection to their community.
    def resolve_discord_id
      user = ESM::User.find_by_discord_id(discord_id)

      return result(:unknown, discord_id:) if user.nil? || !member?(user)
      return result(:unregistered, discord_id:) unless user.registered?

      result(:steam_uid, steam_uid: user.steam_uid, discord_id:)
    end

    # A bot that cannot be asked is not taken as a yes
    def member?(user)
      @community.membership_for(user).present?
    rescue ESM::Service::API::Unreachable, ESM::Service::API::RemoteError => e
      Rails.logger.warn("[PlayerLookup] membership unavailable: #{e.message}")
      false
    end

    def result(kind, **)
      Result.new(kind:, query: @query, **)
    end
  end
end
