# frozen_string_literal: true

module Spec
  #
  # Stands in for the bot on the far side of `ESM::Service::API`, which is the only way the website reaches it.
  #
  # Every answer starts where a bot that cannot see the guild would leave it, so a spec grants only the permission it
  # is actually about and anything it forgets to grant reads as denied. That direction is the point: the opposite
  # default hides a missing grant behind a page that renders everything anyway.
  #
  # One viewer at a time. Membership is not keyed by user, because a browser session holds exactly one, and a spec
  # comparing two people logs in twice rather than holding both at once.
  #
  # @example
  #   service_api.server_connected = true
  #   service_api.administrator = true
  #
  class ServiceAPI
    # Every handler the bot answers, from `service/lib/esm/website/api/handlers`. An action outside this list is a
    # page reaching for something that does not exist, which is worth a failure rather than a silent nil.
    KNOWN_ACTIONS = %i[
      async_command channel channel_send community_channels community_delete community_membership
      community_modifiable_by community_roles community_users ping requests_accept requests_decline
      servers_connected servers_reconnect servers_update sync_command territory_admins user_communities
      user_community_permissions
    ].freeze

    # Whether the viewer may manage the community: the gate behind `check_for_community_access!` and every "Manage"
    # door. Independent of {#administrator}, which is Discord's own permission flag.
    attr_accessor :modifiable_by

    # Whether the viewer holds Discord's administrator permission in the guild. Clears any command allowlist outright.
    attr_accessor :administrator

    # The Discord role ids the viewer holds, matched against a command configuration's `allowlisted_role_ids`.
    attr_accessor :role_ids

    # Whether the target server is connected. This gates commands as well as the sidebar's status line: a command
    # targeting an offline server is denied before its allowlist is ever read.
    attr_accessor :server_connected

    # The guild's roles, as the role pickers read them: `{id:, name:, color:, disabled:}`.
    attr_accessor :roles

    # The guild's channels, grouped as `[category_hash, Array<channel_hash>]` pairs.
    attr_accessor :channels

    class << self
      ##
      # Wires the fake into every spec type that renders a page, so nothing in this suite can reach a bot by
      # forgetting to stub a call. That is the whole reason it is installed centrally rather than required per file
      # the way the rest of `spec/support` is: the specs this replaced passed or failed on whether a bot happened to
      # be running, which is not a property a spec should have.
      #
      # Not every type, on purpose. `spec/lib/esm/service/api_spec.rb` exercises the real `.call` against a throwaway
      # broker, and stubbing it out from under itself would leave it asserting on this fake.
      #
      # @param config [RSpec::Core::Configuration]
      #
      # @return [void]
      #
      def install!(config)
        config.include(Helper)

        installer = proc do
          allow(ESM::Service::API).to receive(:call) { |action, **payload| service_api.call(action, **payload) }

          # A UDP round trip to the owner's own box, lazily loaded into the sidebar of every server page. WebMock
          # cannot intercept it and a spec has nothing to answer it, so it reports nothing, which is the same nil
          # `servers#live` already produces from a server that never replied.
          allow(ESM::Steam::ServerQuery).to receive(:info).and_return(nil)
        end

        config.before(:each, type: :request, &installer)
        config.before(:each, type: :system, &installer)
      end
    end

    def initialize
      @modifiable_by = false
      @administrator = false
      @role_ids = []
      @server_connected = false
      @roles = []
      @channels = []
      @answers = {}
    end

    ##
    # Pins one action's answer outright, for the handlers with no attribute above and for the answers those
    # attributes cannot express, such as the nil a page gets once the guild is gone.
    #
    # @param action [Symbol] the handler name
    # @param value [Object] what it should answer with
    #
    # @return [self]
    #
    def answer(action, value)
      raise unknown_action(action) unless KNOWN_ACTIONS.include?(action.to_sym)

      @answers[action.to_sym] = value
      self
    end

    ##
    # Answers one call the way the bot would.
    #
    # @param action [Symbol] the handler name
    #
    # @return [Object, nil]
    #
    def call(action, **)
      action = action.to_sym
      raise unknown_action(action) unless KNOWN_ACTIONS.include?(action)
      return @answers[action] if @answers.key?(action)

      # Anything not named here answers nil, which is what a handler genuinely returns for a guild the bot cannot
      # see, and every caller of one already folds that nil into an empty list or a false.
      case action
      when :community_modifiable_by then modifiable_by
      when :community_membership then {role_ids:, administrator:}
      when :servers_connected then server_connected
      when :community_roles then roles
      when :community_channels then channels
      end
    end

    ##
    # Gives every system spec one fake and a name to reach it by.
    #
    module Helper
      def service_api
        @service_api ||= ServiceAPI.new
      end
    end

    private

    def unknown_action(action)
      ArgumentError.new(
        "#{action.inspect} is not one of the bot's handlers. Either a page is calling something that does not " \
        "exist, or a handler was added and KNOWN_ACTIONS has not caught up."
      )
    end
  end
end
